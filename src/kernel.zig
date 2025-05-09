const std = @import("std");

const threading = @import("win32").system.threading;

const Fiber = @import("Fiber.zig");
const SharedData = @import("SharedData.zig");

pub var shared: SharedData = undefined;

pub fn schedule(fiber: *Fiber) void {
    shared.lock();
    defer shared.unlock();

    shared.queue.append(shared.gpa, fiber) catch @panic("oom");
    shared.cond.broadcast(); // TODO: TBD: is it safe to `signal`? can non-worker thread receive this event?
}

pub fn spawnThreads(numThreads: usize) void {
    std.debug.assert(shared.started == 0);

    for (0..numThreads) |_| {
        const handle = threading.CreateThread(
            null,
            Fiber.DEFAULT_STACK_SIZE,
            &workerThread,
            null,
            threading.THREAD_CREATION_FLAGS{},
            null,
        ) orelse @panic("failed to create thread");

        _ = handle;
    }

    // wait all threads to initialize
    shared.lock();
    defer shared.unlock();

    while (shared.started != numThreads) {
        shared.wait();
    }
}

pub fn shutdownThreads() void {
    shared.lock();
    defer shared.unlock();

    shared.shutdown = true;
    shared.cond.broadcast();

    // wait worker threads to finish
    while (shared.finished != shared.numThreads) {
        shared.wait();
    }
}

threadlocal var rootFiber: ?*anyopaque = null;

pub fn initRootFiber() void {
    rootFiber = threading.ConvertThreadToFiber(null) orelse @panic("failed to convert current thread to a fiber");
}

pub fn switchToRootFiber() void {
    // note: shared.lock must active!
    threading.SwitchToFiber(rootFiber.?);
}

fn workerThread(threadParam: ?*anyopaque) callconv(.winapi) u32 {
    _ = threadParam;

    initRootFiber();

    shared.lock();
    shared.started += 1;
    shared.cond.broadcast();

    defer {
        shared.finished += 1;
        shared.cond.broadcast();
        shared.unlock();
    }

    while (!shared.shutdown) {
        if (shared.queue.popFront()) |fiber| {
            fiber.switchTo();
            continue;
        }

        shared.wait();
    }

    return 0;
}

pub fn storeFinishedFiberAndActivateNext(fiber: *Fiber) void {
    // note: called on fiber side
    shared.lock();
    defer shared.unlock();

    shared.freeList.append(shared.gpa, fiber) catch @panic("oom");

    // switch back to worker fiber
    // note: we are still under `shared.lock`
    switchToRootFiber();
}

// TODO: active directly next pending fiber without switching to the root
