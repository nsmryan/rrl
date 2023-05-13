const std = @import("std");

const ArrayError = error{NoFreeSpace};

pub fn Array(comptime Elem: type, comptime n: usize) type {
    return struct {
        mem: [n]Elem = [_]Elem{undefined} ** n,
        used: usize = 0,

        pub fn init() @This() {
            var arr = Array(Elem, n){};
            arr.mem = std.mem.zeroes([n]Elem);
            return arr;
        }

        pub fn set(buffer: *@This(), buf: []const Elem) void {
            std.mem.copy(Elem, &buffer.mem, buf);
            buffer.used = buf.len;
        }

        pub fn slice(buffer: *@This()) []Elem {
            return buffer.mem[0..buffer.used];
        }

        pub fn constSlice(buffer: *const @This()) []const Elem {
            return buffer.mem[0..buffer.used];
        }

        pub fn push(buffer: *@This(), elem: Elem) ArrayError!void {
            if (buffer.used == n) {
                return ArrayError.NoFreeSpace;
            } else {
                buffer.mem[buffer.used] = elem;
                buffer.used += 1;
            }
        }

        pub fn contains(buffer: *const @This(), elem: Elem) bool {
            for (buffer.mem) |cur| {
                if (std.meta.eql(cur, elem)) {
                    return true;
                }
            }
            return false;
        }
    };
}

pub fn Buffer(comptime n: usize) type {
    return Array(u8, n);
}
