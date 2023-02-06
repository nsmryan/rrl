const std = @import("std");

pub fn Array(comptime Elem: type, comptime n: usize) type {
    return struct {
        mem: [n]Elem = [_]Elem{undefined} ** n,
        used: usize = 0,

        pub fn init() @This() {
            return Buffer(n){};
        }

        pub fn set(buffer: *@This(), buf: []const Elem) void {
            std.mem.copy(Elem, &buffer.mem, buf);
            buffer.used = buf.len;
        }

        pub fn slice(buffer: *@This()) []Elem {
            return buffer.mem[0..buffer.used];
        }
    };
}

pub fn Buffer(comptime n: usize) type {
    return Array(u8, n);
}
