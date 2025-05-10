const std = @import("std");

threadlocal var traceBuffer: Buffer = .{};

pub fn initTracing() void {
    @panic("not implemented");
}

pub fn deinitTracing() void {
    @panic("not implemented");
}

pub fn startEvent(name: []const u8) EventId {
    _ = name;
    @panic("not implemented");
}

pub fn stopEvent(id: EventId) void {
    _ = id;
    @panic("not implemented");
}

pub fn dumpTraces(output: std.io.AnyWriter) void {
    _ = output;
    @panic("not implemented");
}

pub fn EventAttrib(T: type) type {
    // TODO: check supported type:
    //   * i32, u32, i64, u64
    //   * f32
    //   * []const u8
    // TODO: register event name and store interned id
    return struct {
        const Self = @This();
        name: []const u8,
        id: u32,

        pub fn register(name: []const u8) Self {
            _ = name;
            @panic("not implemented");
        }

        pub fn write(self: *Self, id: EventId, value: T) void {
            _ = self;
            _ = id;
            _ = value;
            @panic("not implemented");
        }
    };
}

pub const EventId = struct {};

const Buffer = struct {
    const Self = @This();

    const BLOCK_SIZE = 64 * 1024;
    head: ?*Block = null,
    tail: ?*Block = null,

    const Block = struct {
        buf: [BLOCK_SIZE]u8,
        count: usize,
        next: ?*Block = null,
    };

    pub fn write(self: *Self, data: *const anyopaque, len: usize) void {
        _ = self;
        _ = data;
        _ = len;
        @panic("not implemented");
    }
};
