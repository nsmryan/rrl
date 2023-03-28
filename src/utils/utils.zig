const std = @import("std");

pub const comp = @import("comp.zig");
pub const astar = @import("astar.zig");
pub const intern = @import("intern.zig");
pub const timer = @import("timer.zig");
pub const buffer = @import("buffer.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}

pub fn baseName(name: []const u8) []const u8 {
    if (std.mem.lastIndexOf(u8, name, ".")) |last_index| {
        return name[(last_index + 1)..];
    } else {
        return name;
    }
}
