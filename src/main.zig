const std = @import("std");
const print = std.debug.print;

const lib = @import("fibers_proto");

fn spawnRunnable(gpa: std.mem.Allocator, runnable: anytype) void {
    const T = @TypeOf(runnable);

    const Wrapper = struct {
        const Self = @This();

        data: T,
        gpa: std.mem.Allocator,

        fn run(self: *Self) void {
            self.data.run();
        }

        fn deinit(self: *Self) void {
            const alloc = self.gpa;
            alloc.destroy(self);
        }
    };

    const wrp = gpa.create(Wrapper) catch @panic("oom");
    wrp.* = .{
        .data = runnable,
        .gpa = gpa,
    };

    lib.spawnTask(Wrapper, Wrapper.run, wrp, Wrapper.deinit);
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer {
        _ = gpa.deinit();
    }

    print("initializing...\n", .{});
    lib.initFiberEngine(gpa.allocator(), 4);

    defer {
        print("terminating...\n", .{});
        lib.termFiberEngine();
        print("done.\n", .{});
    }

    const Worker = struct {
        id: usize,
        finished: *lib.Event,

        fn run(self: *@This()) void {
            defer self.finished.set();

            for (0..10) |k| {
                print("{} - {}\n", .{ self.id, k });
                // TBD: we can implement `timeout` to sleep without cpu usage
                std.Thread.sleep(100 * std.time.ns_per_ms);
            }
        }
    };

    var events: [16]lib.Event = undefined;
    for (&events, 0..) |*ev, k| {
        ev.* = .{};

        spawnRunnable(gpa.allocator(), Worker{
            .id = k,
            .finished = ev,
        });
    }

    const WaitAll = struct {
        events: []lib.Event,
        finished: *lib.Event,

        fn run(self: *@This()) void {
            for (self.events) |*ev| {
                ev.wait();
            }
            self.finished.set();
        }
    };

    var finished = lib.Event{};
    spawnRunnable(gpa.allocator(), WaitAll{
        .events = &events,
        .finished = &finished,
    });

    finished.wait();
}
