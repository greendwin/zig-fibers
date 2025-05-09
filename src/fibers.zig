const std = @import("std");

const threading = @import("win32").system.threading;

const kernel = @import("kernel.zig");

pub const DEFAULT_STACK_SIZE = 8 * 1024;

var fibersMux: std.Thread.Mutex = .{};
var fibers: std.ArrayList(*Fiber) = undefined;

pub fn init(gpa: std.mem.Allocator) void {
    fibers = std.ArrayList(*Fiber).initCapacity(gpa, 16) catch @panic("oom");
}

pub fn deinit() void {
    const gpa = fibers.allocator;

    for (fibers.items) |f| {
        switch (f.*) {
            inline else => |*x| x.deinit(),
        }
        gpa.destroy(f);
    }
    fibers.deinit();
}

pub const FiberType = enum {
    callback,
    thread,
};

pub const Fiber = union(FiberType) {
    callback: FiberCallback,
    thread: FiberThread,

    pub fn threadGroup(self: *Fiber) ?usize {
        switch (self.*) {
            .callback => return null,
            .thread => |x| return x.threadGroup,
        }
    }

    pub fn handle(self: *Fiber) *anyopaque {
        switch (self.*) {
            inline else => |x| return x.handle,
        }
    }
};

const FiberCallback = struct {
    handle: *anyopaque,
    cb: Callback,

    fn deinit(self: *FiberCallback) void {
        self.cb.resetData();
        threading.DeleteFiber(self.handle);
        self.* = undefined;
    }
};

pub const Callback = struct {
    callback: *const fn (?*anyopaque) void,
    data: ?*anyopaque = null,
    dataDeinit: ?*const fn (?*anyopaque) void = null,

    fn resetData(self: *Callback) void {
        if (self.dataDeinit) |dd| {
            dd(self.data);
        }
        self.data = null;
        self.dataDeinit = null;
    }
};

pub fn createFromCallback(callback: Callback) *Fiber {
    const fib = createFiberUninit();
    const handle = threading.CreateFiber(
        DEFAULT_STACK_SIZE,
        callbackEntrypoint,
        fib,
    ) orelse @panic("failed to create fiber");

    fib.* = .{ .callback = .{
        .cb = callback,
        .handle = handle,
    } };

    return fib;
}

const FiberThread = struct {
    handle: *anyopaque,
    threadGroup: ?usize, // exclusive run group

    fn deinit(self: *FiberThread) void {
        _ = self;
    }
};

pub fn createFromThread(handle: *anyopaque, threadGroup: ?usize) *Fiber {
    const fib = createFiberUninit();
    fib.* = .{ .thread = .{
        .handle = handle,
        .threadGroup = threadGroup,
    } };
    return fib;
}

fn createFiberUninit() *Fiber {
    const gpa = fibers.allocator;
    const fib = gpa.create(Fiber) catch @panic("oom");

    // register created fiber in a list of all allocated fibers
    fibersMux.lock();
    defer fibersMux.unlock();

    fibers.append(fib) catch @panic("oom");

    return fib;
}

fn callbackEntrypoint(threadParam: ?*anyopaque) callconv(.winapi) void {
    const self: *Fiber = @ptrCast(@alignCast(threadParam.?));

    // note: we entered here on *LOCKED* `shared` mutex
    kernel.shared.unlock();

    const cb = &self.callback.cb;

    while (true) {
        // invoke user code
        cb.callback(cb.data);

        // clean user data
        cb.resetData();

        kernel.storeFinishedFiberAndActivateNext(self);
    }
}
