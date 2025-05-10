const std = @import("std");

const Fiber = @import("fibers.zig").Fiber;
const kernel = @import("kernel.zig");

pub fn Channel(T: type) type {
    return struct {
        const Self = @This();

        closed: bool = false,
        pendingWrite: FiberQueue = .{},
        pendingRead: FiberQueue = .{},

        pub fn write(self: *Self, data: T) void {
            kernel.shared.lock();
            defer kernel.shared.unlock();

            if (self.closed) {
                @panic("writing to closed channel");
            }

            if (self.pendingRead.popFront()) |reader| {
                const dst: *T = @ptrCast(@alignCast(reader.data_ptr));
                dst.* = data;
                reader.ok = true;
                kernel.scheduleNoLock(reader.fiber);
                return;
            }

            var node: FiberQueue.Node = .{
                .fiber = kernel.getCurrentFiber(),
                .data_ptr = @constCast(&data),
            };
            self.pendingWrite.append(&node);

            // sleep until `reader` awakes us
            kernel.switchToNextNoLock();

            // writes cannot be canceled like reads
            std.debug.assert(node.ok);
        }

        pub fn read(self: *Self) ?T {
            kernel.shared.lock();
            defer kernel.shared.unlock();

            var data: T = undefined;

            if (self.pendingWrite.popFront()) |writer| {
                const src: *const T = @ptrCast(@alignCast(writer.data_ptr));
                data = src.*;
                writer.ok = true;
                kernel.scheduleNoLock(writer.fiber);

                if (self.closed and self.pendingWrite.isEmpty()) {
                    // it was the last writer in a closed channel
                    // wake up the rest of readers there is no more data
                    while (self.pendingRead.popFront()) |reader| {
                        reader.ok = false;
                        kernel.scheduleNoLock(reader.fiber);
                    }
                }

                return data;
            }

            if (self.closed) {
                // there is no pending writer and channel is closed
                // return immediately
                return null;
            }

            var node: FiberQueue.Node = .{
                .fiber = kernel.getCurrentFiber(),
                .data_ptr = &data,
            };
            self.pendingRead.append(&node);

            // wait until writer awakes us
            kernel.switchToNextNoLock();

            if (!node.ok) {
                std.debug.assert(self.closed);
                std.debug.assert(self.pendingWrite.isEmpty());
                return null;
            }

            return data;
        }

        pub fn close(self: *Self) void {
            kernel.shared.lock();
            defer kernel.shared.unlock();

            if (self.closed) {
                @panic("channel was already closed");
            }

            self.closed = true;

            if (!self.pendingWrite.isEmpty()) {
                // last read will wake up the rest of readers
                return;
            }

            while (self.pendingRead.popFront()) |reader| {
                reader.ok = false;
                kernel.scheduleNoLock(reader.fiber);
            }
        }
    };
}

const FiberQueue = struct {
    const Self = @This();
    head: ?*Node = null,
    tail: ?*Node = null,

    pub const Node = struct {
        fiber: *Fiber,
        data_ptr: *anyopaque,
        ok: bool = false, // wheather data was read or written

        // note: don't store `prev` since we need only `fifo` behavior
        next: ?*Node = null,
    };

    pub inline fn isEmpty(self: *Self) bool {
        return self.head == null;
    }

    pub fn append(self: *Self, node: *Node) void {
        std.debug.assert(node.next == null);

        if (self.tail) |tail| {
            tail.next = node;
        } else {
            std.debug.assert(self.head == null);
            self.head = node;
        }
        self.tail = node;
    }

    pub fn popFront(self: *Self) ?*Self.Node {
        const head = self.head orelse return null;
        self.head = head.next;

        if (head.next == null) {
            self.tail = null;
        }

        return head;
    }
};
