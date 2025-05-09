const std = @import("std");

const Self = @This();
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},

pub inline fn lock(self: *Self) void {
    self.mutex.lock();
}

pub inline fn unlock(self: *Self) void {
    self.mutex.unlock();
}

pub inline fn wait(self: *Self) void {
    self.cond.wait(&self.mutex);
}

pub inline fn broadcast(self: *Self) void {
    self.cond.broadcast();
}
