const std = @import("std");

const Buffer = @import("Buffer.zig");

threadlocal var traceBuffer: Buffer = undefined;

const PacketType = enum(u8) {
    register_attrib = 0,
    start_event = 1,
    stop_event = 2,
    attrib = 3,
};

pub const EventId = struct {
    id: u64,
};

pub const AttribType = enum(u8) {
    int, // 8 bytes
    string, // 4 bytes + N
};

pub fn initThread(gpa: std.mem.Allocator) void {
    traceBuffer = .init(gpa);
}

pub fn writeRegAttrib(attrib_id: u16, tp: AttribType, name: []const u8) void {
    traceBuffer.write(u8, PacketType.register_attrib);
    traceBuffer.write(u16, attrib_id);
    traceBuffer.write(u8, tp);
    traceBuffer.write(u16, @intCast(name.len));
    traceBuffer.writeBytes(name);
}

pub fn writeIntAttrib(event_id: EventId, attrib_id: u16, val: i64) void {
    traceBuffer.write(u8, PacketType.attrib);
    traceBuffer.write(u64, event_id.id);
    traceBuffer.write(u16, attrib_id);
    traceBuffer.write(i64, val);
}

pub fn writeStrAttrib(event_id: EventId, attrib_id: u16, text: []const u8) void {
    traceBuffer.write(u8, PacketType.attrib);
    traceBuffer.write(u64, event_id.id);
    traceBuffer.write(u16, attrib_id);
    traceBuffer.write(u16, @intCast(text.len));
    traceBuffer.writeBytes(text.len);
}
