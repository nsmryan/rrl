const std = @import("std");

pub fn Buffer(comptime n: usize) type {
    return struct {
        mem: [n]u8 = [_]u8{0} ** n,
        used: usize = 0,

        pub fn init() @This() {
            return Buffer(n){};
        }

        pub fn set(buffer: *@This(), buf: []const u8) void {
            std.mem.copy(u8, &buffer.mem, buf);
            buffer.used = buf.len;
        }

        pub fn slice(buffer: *@This()) []u8 {
            return buffer.mem[0..buffer.used];
        }
    };
}
