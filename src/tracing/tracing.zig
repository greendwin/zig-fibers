const std = @import("std");

const binary_format = @import("binary_format.zig");
const event_attribs = @import("event_attribs.zig");
pub const EventStrAttrib = event_attribs.EventStrAttrib;
pub const EventIntAttrib = event_attribs.EventIntAttrib;
pub const registerAttrib = event_attribs.registerAttrib;
pub const EventId = @import("binary_format.zig").EventId;

const name_attrib: EventStrAttrib = undefined;
const parent_attrib: EventIntAttrib = undefined;

const time_zero = std.time.Instant.now() catch unreachable;

pub fn init(gpa: std.mem.Allocator) void {
    binary_format.initThread(gpa);
    event_attribs.init(gpa);
    name_attrib = registerAttrib(EventStrAttrib, "name");
    parent_attrib = registerAttrib(EventIntAttrib, "parent");

    @panic("not implemented");
}

pub fn deinit() void {
    @panic("not implemented");
}

pub fn startEvent(name: []const u8, parent: ?EventId) EventId {
    // generate event id
    // name_attrib.write(event_id, name);
    _ = name;
    _ = parent;
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
