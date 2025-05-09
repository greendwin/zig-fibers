//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const threading = @import("win32").system.threading;

const Handle = *anyopaque;
const DEFAULT_STACK_SIZE: usize = 8 * 1024;

const SharedData = struct {
    numThreads: u32 = 0,
    started: u32 = 0,
    shutdown: bool = false,
    finished: u32 = 0,

    mux: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},

    pub inline fn lock(self: *SharedData) void {
        self.mux.lock();
    }

    pub inline fn unlock(self: *SharedData) void {
        self.mux.unlock();
    }
    pub inline fn wait(self: *SharedData) void {
        self.cond.wait(&self.mux);
    }
};

var shared: SharedData = .{};

pub fn initFiberEngine(numThreads: u32) void {
    // convert our own thread to a fiber so it's part of the system
    const mainFiber = threading.ConvertThreadToFiber(null) orelse @panic("failed to convert current thread to a fiber");
    _ = mainFiber;

    std.debug.assert(shared.numThreads == 0);
    shared.numThreads = numThreads;

    for (0..numThreads) |_| {
        const handle = threading.CreateThread(
            null,
            DEFAULT_STACK_SIZE,
            &workerThread,
            null,
            threading.STACK_SIZE_PARAM_IS_A_RESERVATION,
            null,
        ) orelse @panic("failed to create thread");

        _ = handle;
    }

    // wait all threads to initialize
    shared.lock();
    defer shared.unlock();

    while (shared.started != numThreads) {
        shared.wait();
    }
}

pub fn termFiberEngine() void {
    shared.lock();
    defer shared.unlock();

    shared.shutdown = true;

    while (shared.finished != shared.numThreads) {
        shared.wait();
    }
}

fn workerThread(threadParam: ?*anyopaque) callconv(.winapi) u32 {
    _ = threadParam;

    const fiber = threading.ConvertThreadToFiber(null) orelse @panic("failed to convert worker thread to a fiber");
    _ = fiber;

    shared.lock();
    defer shared.unlock();

    shared.started += 1;
    shared.cond.broadcast();

    defer {
        shared.finished += 1;
        shared.cond.broadcast();
    }

    while (!shared.shutdown) {
        // ...
        shared.wait();
    }

    return 0;
}
