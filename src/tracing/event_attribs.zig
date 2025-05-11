const std = @import("std");

const binary_format = @import("binary_format.zig");
const tracing = @import("tracing.zig");
const EventId = tracing.EventId;

var attribs: std.StringHashMap(u16) = undefined;

pub fn init(gpa: std.mem.Allocator) void {
    attribs = std.StringArrayHashMap(u16).init(gpa);
}

pub fn deinit() void {
    attribs.deinit();
}

/// register attribute, pass `EventIntAttrib` or `EventStrAttrib` as type argument
pub fn registerAttrib(T: type, name: []const u8) T {
    const entry = attribs.getOrPutValue(name, attribs.count()) catch @panic("oom");
    const attrib_id = entry.value_ptr.*;

    return .{
        .name = name,
        .attrib_id = attrib_id,
    };
}

pub const EventIntAttrib = struct {
    const Self = @This();

    name: []const u8,
    attrib_id: u16,

    pub fn write(self: *Self, event_id: EventId, value: anytype) void {
        const val64: i64 = @intCast(value);
        binary_format.writeIntAttrib(
            event_id,
            self.name.id,
            val64,
        );
    }
};

pub const EventStrAttrib = struct {
    const Self = @This();

    name: []const u8,
    attrib_id: u16,

    pub fn write(self: *Self, event_id: EventId, text: []const u8) void {
        binary_format.writeStrAttrib(
            event_id,
            self.name.id,
            text,
        );
    }
};
