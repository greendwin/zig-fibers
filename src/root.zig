const std = @import("std");
const testing = std.testing;

const threading = @import("win32").system.threading;

pub const Condition = @import("Condition.zig");
const Fiber = @import("Fiber.zig");
const kernel = @import("kernel.zig");

pub fn initFiberEngine(gpa: std.mem.Allocator, numThreads: u32) void {
    // convert our own thread to a fiber so it's part of the system
    kernel.initRootFiber();

    kernel.shared = .init(gpa, numThreads);
    kernel.spawnThreads(numThreads);
}

pub fn termFiberEngine() void {
    kernel.shutdownThreads();
    kernel.shared.deinit();
}

pub fn spawnTask(T: type, callback: *const fn (*T) void, data: *T, dataDeinit: ?*const fn (*T) void) void {
    // TODO: peak fiber from a free list
    const fiber = Fiber.create(kernel.shared.gpa, .{
        .callback = @ptrCast(callback),
        .data = data,
        .dataDeinit = @ptrCast(dataDeinit),
    });

    kernel.schedule(fiber);
}
