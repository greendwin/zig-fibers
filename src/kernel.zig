const std = @import("std");

const threading = @import("win32").system.threading;

const fibers = @import("fibers.zig");
const Fiber = fibers.Fiber;
const SharedData = @import("SharedData.zig");

pub var shared: SharedData = undefined;

pub inline fn scheduleNoLock(fiber: *Fiber) void {
    shared.queue.append(shared.gpa, fiber) catch @panic("oom");
    shared.cond.broadcast(); // TODO: TBD: is it safe to `signal`? can non-worker thread receive this event?
}

pub fn spawnThreads(numThreads: usize) void {
    std.debug.assert(shared.started == 0);

    for (0..numThreads) |_| {
        const handle = threading.CreateThread(
            null,
            fibers.DEFAULT_STACK_SIZE,
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

threadlocal var rootFiber: ?*Fiber = null;

pub fn initFiberFromThread(worker: bool) void {
    const handle = threading.ConvertThreadToFiber(null) orelse @panic("failed to convert current thread to a fiber");
    const fromThread = fibers.createFromThread(handle);
    currentFiber = fromThread;

    if (worker) {
        rootFiber = fromThread;
        return;
    }

    // special case for non-worker root threads

    // TODO: bind `fromThread` to current thread!

    // create special callback fiber with worker loop
    // this allows to original thread to use `Event` (i.e. move its fiber in sleeping state)
    rootFiber = fibers.createFromCallback(.{ .callback = workerCallback });
}

threadlocal var currentFiber: ?*Fiber = null;

pub inline fn getCurrentFiber() *Fiber {
    return currentFiber orelse @panic(
        "trying to retrieve current fiber in non-fiber context, " ++
            "make sure to run `initFiberEngine`",
    );
}

pub fn switchToNextNoLock() void {
    if (shared.queue.popFront()) |fiber| {
        switchToFiberNoLock(fiber);
    } else {
        switchToFiberNoLock(rootFiber.?);
    }
}

fn switchToFiberNoLock(fiber: *Fiber) void {
    std.debug.assert(currentFiber != fiber);
    currentFiber = fiber;
    threading.SwitchToFiber(fiber.handle());
}

fn workerThread(param: ?*anyopaque) callconv(.winapi) u32 {
    _ = param;

    initFiberFromThread(true);

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
            switchToFiberNoLock(fiber);
            continue;
        }

        shared.wait();
    }

    return 0;
}

fn workerCallback(param: ?*anyopaque) void {
    _ = param;

    shared.lock();
    defer shared.unlock();

    while (!shared.shutdown) {
        if (shared.queue.popFront()) |fiber| {
            switchToFiberNoLock(fiber);
            continue;
        }

        shared.wait();
    }
}

pub fn storeFinishedFiberAndActivateNext(fiber: *Fiber) void {
    std.debug.assert(currentFiber == fiber);

    const tp: fibers.FiberType = fiber.*;
    std.debug.assert(tp == .callback);

    // note: called on fiber side
    shared.lock();
    defer shared.unlock();

    shared.freeList.append(shared.gpa, fiber) catch @panic("oom");

    switchToNextNoLock();
}
