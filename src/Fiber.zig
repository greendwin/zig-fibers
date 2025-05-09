const std = @import("std");

const threading = @import("win32").system.threading;

const kernel = @import("kernel.zig");

const Self = @This();
pub const DEFAULT_STACK_SIZE = 8 * 1024;

cb: Callback,
handle: *anyopaque,

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

pub fn create(gpa: std.mem.Allocator, callback: Callback) *Self {
    const fiber = gpa.create(Self) catch @panic("oom");
    fiber.* = .{
        .cb = callback,
        .handle = threading.CreateFiber(
            DEFAULT_STACK_SIZE,
            entrypoint,
            fiber,
        ) orelse @panic("failed to create fiber"),
    };

    return fiber;
}

pub fn destroy(self: *Self, gpa: std.mem.Allocator) void {
    self.cb.resetData();
    threading.DeleteFiber(self.handle);
    self.* = undefined;

    gpa.destroy(self);
}

pub fn switchTo(self: *Self) void {
    threading.SwitchToFiber(self.handle);
}

fn entrypoint(threadParam: ?*anyopaque) callconv(.winapi) void {
    const self: *Self = @ptrCast(@alignCast(threadParam.?));

    // note: we entered here on *LOCKED* `shared` mutex
    kernel.shared.unlock();

    while (true) {
        // invoke user code
        self.cb.callback(self.cb.data);

        // clean user data
        self.cb.resetData();

        kernel.storeFinishedFiberAndActivateNext(self);
    }
}
