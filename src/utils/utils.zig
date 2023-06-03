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

// This function takes a lowerCamelCase name and converts it into a first and second component
// that are split after the first word after the center of the name.
//
// This function leaks its allocation, so only use it with a frame allocator where freeing is not necessary.
pub fn displayName(name: []const u8, allocator: Allocator) !struct { first: []const u8, second: []const u8 } {
    var result = ArrayList(u8).init(allocator);
    var index: usize = 0;
    var second_index: usize = 0;
    var first: []const u8 = name;
    var second: []const u8 = "";
    for (name) |chr| {
        if (std.ascii.isUpper(chr)) {
            try result.append(' ');
            index += 1;
            if (second_index == 0 and index > name.len / 2) {
                first = result.items[0..index];
                second_index = index;
            }
        }
        try result.append(std.ascii.toLower(chr));
        index += 1;
    }
    if (second_index != 0) {
        second = result.items[second_index..];
    }
    return .{ .first = first, .second = second };
}
