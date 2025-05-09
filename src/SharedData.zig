const std = @import("std");

const Condition = @import("Condition.zig");
const Fiber = @import("Fiber.zig");
const ListDequeUnmanaged = @import("list_deque.zig").ListDequeUnmanaged;

const Self = @This();
numThreads: u32,
started: u32 = 0,
shutdown: bool = false,
finished: u32 = 0,

freeList: std.ArrayListUnmanaged(*Fiber),
queue: ListDequeUnmanaged(*Fiber),
cond: Condition = .{},

gpa: std.mem.Allocator,

pub fn init(gpa: std.mem.Allocator, numThreads: u32) Self {
    return .{
        .numThreads = numThreads,
        .freeList = std.ArrayListUnmanaged(*Fiber).initCapacity(gpa, 16) catch @panic("oom"),
        .queue = ListDequeUnmanaged(*Fiber).initCapacity(gpa, 256) catch @panic("oom"),
        .gpa = gpa,
    };
}

pub fn deinit(self: *Self) void {
    for (self.freeList.items) |f| {
        f.destroy(self.gpa);
    }
    self.freeList.deinit(self.gpa);

    for (self.queue.data.items[self.queue.offset..]) |f| {
        f.destroy(self.gpa);
    }
    self.queue.deinit(self.gpa);
    self.* = undefined;
}

pub inline fn lock(self: *Self) void {
    self.cond.lock();
}

pub inline fn unlock(self: *Self) void {
    self.cond.unlock();
}

pub inline fn wait(self: *Self) void {
    self.cond.wait();
}
