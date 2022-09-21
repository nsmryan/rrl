const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn white() Color {
        return Color.new(255, 255, 255, 255);
    }

    pub fn black() Color {
        return Color.new(0, 0, 0, 255);
    }

    pub fn new(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

pub fn lerp(first: f32, second: f32, scale: f32) f32 {
    return first + ((second - first) * scale);
}

test "lerp" {
    var first: f32 = 0.0;
    var second: f32 = 1.0;
    try std.testing.expectApproxEqRel(@as(f32, 0.5), lerp(first, second, 0.5), 0.0001);
}
