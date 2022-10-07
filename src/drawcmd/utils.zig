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
};

pub const Pos = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Pos {
        return Pos{ .x = x, .y = y };
    }
};

pub const Direction = enum {
    right,
    downRight,
    down,
    downLeft,
    left,
    upLeft,
    up,
    upRight,
    center,
};
