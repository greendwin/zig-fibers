const std = @import("std");
const testing = std.testing;

const threading = @import("win32").system.threading;

const fibers = @import("fibers.zig");
const Fiber = fibers.Fiber;
const kernel = @import("kernel.zig");
pub const Channel = @import("primitives/channel.zig").Channel;
pub const Event = @import("primitives/Event.zig");
pub const WaitGroup = @import("primitives/WaitGroup.zig");
pub const spawnRunnable = @import("runnable.zig").spawnRunnable;

pub fn initFiberEngine(gpa: std.mem.Allocator, numThreads: u32) void {
    kernel.shared = .init(gpa, numThreads);
    fibers.init(gpa); // technically, fibers can use `kernel`
    kernel.initFiberFromThread(false); // convert our own thread to a fiber so it's part of the system
    kernel.spawnThreads(numThreads);
}

pub fn termFiberEngine() void {
    kernel.shutdownThreads();
    fibers.deinit();
    kernel.shared.deinit();
}

pub fn spawnTask(T: type, callback: *const fn (*T) void, data: *T, dataDeinit: ?*const fn (*T) void) void {
    const cb: fibers.Callback = .{
        .callback = @ptrCast(callback),
        .data = data,
        .dataDeinit = @ptrCast(dataDeinit),
    };

    kernel.shared.lock();
    defer kernel.shared.unlock();

    if (kernel.shared.freeList.pop()) |fiber| {
        std.debug.assert(fiber.getType() == .callback);
        fiber.callback.cb = cb;
        kernel.scheduleNoLock(fiber);
        return;
    }

    const fiber = fibers.createFromCallback(cb);
    kernel.scheduleNoLock(fiber);
}
