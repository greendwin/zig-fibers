const std = @import("std");

const spawnTask = @import("root.zig").spawnTask;

pub const DeinitType = enum {
    nodeinit,
    deinit,
    deinit_gpa,
};

pub fn spawnRunnable(gpa: std.mem.Allocator, runnable: anytype, comptime deinit: DeinitType) void {
    const T = @TypeOf(runnable);
    const W = Wrapper(T, deinit);

    const wrp = gpa.create(W) catch @panic("oom");
    wrp.* = .{
        .data = runnable,
        .gpa = gpa,
    };

    spawnTask(W, W.run, wrp, W.deinit);
}

fn Wrapper(T: type, comptime deinitType: DeinitType) type {
    return struct {
        const Self = @This();

        data: T,
        gpa: std.mem.Allocator,

        fn run(self: *Self) void {
            self.data.run();
        }

        fn deinit(self: *Self) void {
            switch (deinitType) {
                .nodeinit => {},
                .deinit => self.data.deinit(),
                .deinit_gpa => self.data.deinit(self.gpa),
            }

            const alloc = self.gpa;
            alloc.destroy(self);
        }
    };
}
