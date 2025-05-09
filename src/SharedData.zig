const std = @import("std");

const Fiber = @import("fibers.zig").Fiber;
const ListDequeUnmanaged = @import("list_deque.zig").ListDequeUnmanaged;
const ThreadCondition = @import("ThreadCondition.zig");

const Self = @This();
numThreads: u32,
started: u32 = 0,
shutdown: bool = false,
finished: u32 = 0,

freeList: std.ArrayListUnmanaged(*Fiber),
queue: ListDequeUnmanaged(*Fiber),
cond: ThreadCondition = .{},

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
    self.freeList.deinit(self.gpa);
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
