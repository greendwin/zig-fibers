const std = @import("std");
const print = std.debug.print;

const lib = @import("fibers_proto");

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

        pub fn run(self: *@This()) void {
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

        lib.spawnRunnable(gpa.allocator(), Worker{
            .id = k,
            .finished = ev,
        }, .nodeinit);
    }

    const WaitAll = struct {
        events: []lib.Event,
        finished: *lib.Event,

        pub fn run(self: *@This()) void {
            for (self.events) |*ev| {
                ev.wait();
            }
            self.finished.set();
        }
    };

    var finished = lib.Event{};
    lib.spawnRunnable(gpa.allocator(), WaitAll{
        .events = &events,
        .finished = &finished,
    }, .nodeinit);

    finished.wait();
}

// TODO: implement `Channel`
// [ ] non-buffered send/write
// [ ] channel closing
// [ ] buffered channels
// TODO: allow to reset `Events`
// TODO: add wait group
// TODO: implement `select` for reading from multiple channels
