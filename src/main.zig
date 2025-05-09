//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const print = std.debug.print;

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("fibers_proto");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer {
        _ = gpa.deinit();
    }

    print("Initializing fiber engine...\n", .{});
    lib.initFiberEngine(gpa.allocator(), 4);
    print("Initialized!\n", .{});

    const Data = struct {
        cond: lib.Condition = .{},
        finished: bool = false,

        pub fn run(self: *@This()) void {
            print("Running from the spawned fiber!\n", .{});
            std.Thread.sleep(1 * std.time.ns_per_s);
            print("Finished fake work\n", .{});

            self.cond.lock();
            defer self.cond.unlock();

            self.finished = true;
            self.cond.broadcast();
        }
    };

    {
        var data = Data{};

        lib.spawnTask(Data, Data.run, &data, null);

        data.cond.lock();
        defer data.cond.unlock();

        while (!data.finished) {
            data.cond.wait();
        }
    }

    print("Terminating fiber engine...\n", .{});
    lib.termFiberEngine();
    print("Done.\n", .{});
}
