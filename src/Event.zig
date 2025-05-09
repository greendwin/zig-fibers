const std = @import("std");

const Fiber = @import("fibers.zig").Fiber;
const kernel = @import("kernel.zig");

const Self = @This();
activated: bool = false,
pending: ?*Node = null,

const Node = struct {
    fiber: *Fiber,
    next: ?*Node,
};

pub fn set(self: *Self) void {
    kernel.shared.lock();
    defer kernel.shared.unlock();

    self.activated = true;

    var cur = self.pending;
    self.pending = null;

    while (cur) |node| {
        kernel.scheduleNoLock(node.fiber);
        cur = node.next;
    }
}

pub fn wait(self: *Self) void {
    kernel.shared.lock();
    defer kernel.shared.unlock();

    if (self.activated) {
        // nothing to wait
        std.debug.assert(self.pending == null);
        return;
    }

    var node: Node = .{
        .fiber = kernel.getCurrentFiber(),
        .next = self.pending,
    };

    self.pending = &node;

    // stop execution until `set` method awake us
    kernel.switchToNext();

    std.debug.assert(self.activated);
}
