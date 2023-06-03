const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

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

//pub fn lowerCamelToSpaced(name: []const u8, allocator: Allocator) !ArrayList(u8) {
//    var result = ArrayList(u8).init(allocator);
//    for (name) |chr| {
//        if (std.ascii.isUpper(chr)) {
//            try result.append(' ');
//        }
//        try result.append(std.ascii.toLower(chr));
//    }
//    return result;
//}
