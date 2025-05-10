const std = @import("std");
const AtomicRmwOp = std.builtin.AtomicRmwOp;

const Event = @import("Event.zig");

const Self = @This();

counter: u32 = 0,
finished: Event = .{},

pub fn add(self: *Self, count: usize) void {
    _ = @atomicRmw(
        u32,
        &self.counter,
        .Add,
        @intCast(count),
        .acquire,
    );
}

pub fn done(self: *Self) void {
    const prev = @atomicRmw(
        u32,
        &self.counter,
        .Sub,
        1,
        .release,
    );

    std.debug.assert(prev > 0);

    if (prev == 1) {
        // we were the last
        self.finished.set();
    }
}

pub fn wait(self: *Self) void {
    self.finished.wait();

    std.debug.assert(self.counter == 0);
    self.finished.resetUnsafe(); // wait group can be reused
}
