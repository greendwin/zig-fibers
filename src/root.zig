const std = @import("std");
const testing = std.testing;

const threading = @import("win32").system.threading;

pub const Event = @import("Event.zig");
const fibers = @import("fibers.zig");
const Fiber = fibers.Fiber;
const kernel = @import("kernel.zig");
pub const ThreadCondition = @import("ThreadCondition.zig");

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
    // TODO: peak fiber from a free list
    const fiber = fibers.createFromCallback(.{
        .callback = @ptrCast(callback),
        .data = data,
        .dataDeinit = @ptrCast(dataDeinit),
    });

    kernel.schedule(fiber);
}
