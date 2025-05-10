const std = @import("std");

const Fiber = @import("fibers.zig").Fiber;
const VecDequeUnmanaged = @import("vec_deque.zig").VecDequeUnmanaged;

pub const ORIGIN_GROUP_ID = 0;

// TBD: it can be a dynamic value, but do we need these groups so often?
pub const MAX_GROUPS: usize = 8;

const Self = @This();
numThreads: u32,
started: u32 = 0,
shutdown: bool = false,
finished: u32 = 0,

freeList: std.ArrayListUnmanaged(*Fiber),
queue: VecDequeUnmanaged(*Fiber),
groups: [MAX_GROUPS]VecDequeUnmanaged(*Fiber),
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},

gpa: std.mem.Allocator,

pub fn init(gpa: std.mem.Allocator, numThreads: u32) Self {
    var r = Self{
        .numThreads = numThreads,
        .freeList = std.ArrayListUnmanaged(*Fiber).initCapacity(gpa, 16) catch @panic("oom"),
        .queue = VecDequeUnmanaged(*Fiber).initCapacity(gpa, 256) catch @panic("oom"),
        .groups = undefined,
        .gpa = gpa,
    };

    for (&r.groups) |*gr| {
        gr.* = VecDequeUnmanaged(*Fiber).initCapacity(gpa, 16) catch @panic("oom");
    }

    return r;
}

pub fn deinit(self: *Self) void {
    self.freeList.deinit(self.gpa);
    self.queue.deinit(self.gpa);

    for (&self.groups) |*gr| {
        gr.deinit(self.gpa);
    }

    self.* = undefined;
}

pub inline fn lock(self: *Self) void {
    self.mutex.lock();
}

pub inline fn unlock(self: *Self) void {
    self.mutex.unlock();
}

pub inline fn wait(self: *Self) void {
    self.cond.wait(&self.mutex);
}
