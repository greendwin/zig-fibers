const std = @import("std");

const Self = @This();

head: *Chunk,
tail: *Chunk,
gpa: std.mem.Allocator,

pub fn init(gpa: std.mem.Allocator) Self {
    const chunk = Chunk.create(gpa);
    return .{
        .head = chunk,
        .tail = chunk,
        .gpa = gpa,
    };
}

pub fn deinit(self: *Self) void {
    var cur: ?*Chunk = self.head;
    while (cur) |chunk| {
        cur = chunk.next;
        self.gpa.free(chunk);
    }
    self.* = undefined;
}

pub fn write(self: *Self, T: type, val: T) void {
    self.writeBytes(@as([*]u8, @ptrCast(&val))[0..@sizeOf(T)]);
}

pub fn writeBytes(self: *Self, data: []const u8) void {
    var rest = data;
    while (true) {
        rest = self.tail.write(rest);
        if (rest.len == 0) {
            break;
        }

        std.debug.assert(self.tail.count == Chunk.BUF_SIZE);

        // allocate more data for the rest bytes
        const new_chunk = Chunk.create(self.gpa);
        self.tail.next = new_chunk;
        self.tail = new_chunk;
    }
}

const Chunk = struct {
    const BUF_SIZE = 8 * 1024 - @sizeOf(u16) - @sizeOf(?*Chunk);
    count: u16,
    buf: [BUF_SIZE]u8,
    next: ?*Chunk,

    pub fn create(gpa: std.mem.Allocator) *Chunk {
        const r = gpa.create(Chunk) catch @panic("oom");
        r.count = 0;
        r.next = null;
        return r;
    }

    pub inline fn freeSize(self: *Chunk) usize {
        return BUF_SIZE - self.count;
    }

    pub fn write(self: *Chunk, data: []const u8) []const u8 {
        const write_len = @min(data.len, self.freeSize());
        @memcpy(
            self.buf[self.count .. self.count + write_len],
            data[0..write_len],
        );

        self.count += write_len;
        return data[write_len..];
    }
};
