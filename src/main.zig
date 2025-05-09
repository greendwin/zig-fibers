const std = @import("std");
const print = std.debug.print;

const lib = @import("fibers_proto");

fn doSomeWork(finished: *lib.Event) void {
    defer finished.set();

    for (0..10) |k| {
        print("{}\n", .{k});
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
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

    var finished = lib.Event{};

    lib.spawnTask(lib.Event, doSomeWork, &finished, null);

    finished.wait();
}
