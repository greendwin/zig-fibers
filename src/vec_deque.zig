const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocError = std.mem.Allocator.Error;

pub fn VecDequeUnmanaged(T: type) type {
    return struct {
        const Self = @This();
        data: []T,
        offset: u32,
        count: u32,

        pub fn initCapacity(gpa: Allocator, capacity: usize) AllocError!Self {
            std.debug.assert(capacity > 0);

            return .{
                .data = try gpa.alloc(T, capacity),
                .offset = 0,
                .count = 0,
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            gpa.free(self.data);
            self.* = undefined;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }

        pub fn append(self: *Self, gpa: Allocator, item: T) AllocError!void {
            if (self.count >= self.data.len) {
                std.debug.assert(self.count == self.data.len);
                try self.expandCapacity(gpa);
            }

            const next: usize = @intCast(self.offset + self.count);
            self.data[@mod(next, self.data.len)] = item;
            self.count += 1;
        }

        fn expandCapacity(self: *Self, gpa: Allocator) AllocError!void {
            const newBuf = try gpa.alloc(T, 2 * self.data.len);

            const pair = self.items();
            @memcpy(newBuf[0..pair.first.len], pair.first);
            @memcpy(newBuf[pair.first.len .. pair.first.len + pair.second.len], pair.second);

            gpa.free(self.data);
            self.data = newBuf;
            self.offset = 0;
        }

        pub const Items = struct {
            first: []T,
            second: []T,
        };

        pub fn items(self: *Self) Items {
            _ = self;
            @panic("not implemented");
        }

        pub fn popFront(self: *Self) ?T {
            if (self.isEmpty()) {
                return null;
            }

            const r = self.data[self.offset];
            self.offset = @mod(self.offset + 1, @as(u32, @intCast(self.data.len)));
            self.count -= 1;
            return r;
        }
    };
}
