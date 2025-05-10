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

    const Sequence = struct {
        count: usize,
        output: *lib.Channel(i32),

        pub fn run(self: *@This()) void {
            defer self.output.close();

            for (0..self.count) |k| {
                self.output.write(@intCast(k));
            }
        }
    };

    var seq: lib.Channel(i32) = .{};
    lib.spawnRunnable(gpa.allocator(), Sequence{
        .count = 1000,
        .output = &seq,
    }, .nodeinit);

    const Worker = struct {
        id: usize,
        input: *lib.Channel(i32),
        waitGroup: *lib.WaitGroup,

        pub fn run(self: *@This()) void {
            defer self.waitGroup.done();

            while (self.input.read()) |x| {
                print("{:2}: {} -> {}\n", .{ self.id, x, x * x });
            }

            // TBD: we can implement `timeout` to sleep without cpu usage
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    };

    const numWorkers = 16;
    var wg: lib.WaitGroup = .{};
    wg.add(numWorkers);
    for (0..numWorkers) |k| {
        lib.spawnRunnable(gpa.allocator(), Worker{
            .id = k,
            .input = &seq,
            .waitGroup = &wg,
        }, .nodeinit);
    }

    const WaitAll = struct {
        waitGroup: *lib.WaitGroup,
        finished: *lib.Event,

        pub fn run(self: *@This()) void {
            self.waitGroup.wait();
            self.finished.set();
        }
    };

    var finished = lib.Event{};
    lib.spawnRunnable(gpa.allocator(), WaitAll{
        .waitGroup = &wg,
        .finished = &finished,
    }, .nodeinit);

    finished.wait();
}

// TODO: reorganize repo to library and examples
// [ ] basic example demonstrating all primitives
// [ ] complex calculation with threads prioritization (setup thread groups)
// [ ] TBD: errors processing

// TODO: add tracing lib that writes execution pipeline
// TODO: vizualize traces

// TODO: add tests
// TODO: add readme

// TODO: implement `Channel`
// [x] non-buffered send/write
// [x] channel closing
// [ ] TBD: buffered channels (maybe special oneshot channels? aka `Future`)

// TODO: implement `select` for reading from multiple channels
// [ ] select read
// [ ] mixed select read/write
// [ ] context-like cancellation

// TODO: timeouts
