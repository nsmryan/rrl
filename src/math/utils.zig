const std = @import("std");

const Pos = @import("pos.zig").Pos;

pub const ASCII_START: usize = 32;
pub const ASCII_END: usize = 127;

pub const Rect = struct {
    x: i32,
    y: i32,
    w: u32,
    h: u32,

    pub fn init(x: i32, y: i32, w: u32, h: u32) Rect {
        return Rect{ .x = x, .y = y, .w = w, .h = h };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn white() Color {
        return Color.init(255, 255, 255, 255);
    }

    pub fn black() Color {
        return Color.init(0, 0, 0, 255);
    }
};

pub const Dims = struct {
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize) Dims {
        return Dims{ .width = width, .height = height };
    }

    pub fn numTiles(dims: *const Dims) usize {
        return dims.width * dims.height;
    }

    pub fn isWithinBounds(dims: *const Dims, position: Pos) bool {
        return position.x >= 0 and position.y >= 0 and position.x < dims.width and position.height < dims.height;
    }

    pub fn toIndex(dims: *const Dims, position: Pos) usize {
        return @intCast(usize, position.x) + @intCast(usize, position.y) * dims.width;
    }

    pub fn clamp(dims: *const Dims, pos: Pos) Pos {
        const new_x = std.math.min(@intCast(i32, dims.width) - 1, std.math.max(0, pos.x));
        const new_y = std.math.min(@intCast(i32, dims.height) - 1, std.math.max(0, pos.y));
        return Pos.init(new_x, new_y);
    }

    pub fn scale(dims: Dims, x_scaler: usize, y_scaler: usize) Dims {
        return Dims.init(dims.width * x_scaler, dims.height * y_scaler);
    }
};
