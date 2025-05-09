const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocError = std.mem.Allocator.Error;

// TODO: implement correct ring-buffer deque with expantion & etc

pub fn ListDequeUnmanaged(T: type) type {
    return struct {
        const Self = @This();
        data: std.ArrayListUnmanaged(T),
        offset: usize,

        pub fn initCapacity(gpa: Allocator, capacity: usize) AllocError!Self {
            return .{
                .offset = 0,
                .data = try std.ArrayListUnmanaged(T).initCapacity(gpa, capacity),
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.data.deinit(gpa);
            self.* = undefined;
        }

        pub fn empty(self: *const Self) bool {
            return self.offset == self.data.items.len;
        }

        pub fn append(self: *Self, gpa: Allocator, item: T) AllocError!void {
            std.debug.assert(self.offset + 1 < self.data.capacity);

            try self.data.append(gpa, item);
        }

        pub fn popFront(self: *Self) ?T {
            if (self.empty()) {
                return null;
            }

            const r = self.data.items[self.offset];
            self.offset += 1;
            return r;
        }
    };
}
