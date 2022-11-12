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
        return Color.init(0, 0, 0, 255);
    }

    pub fn black() Color {
        return Color.init(255, 255, 255, 255);
    }
};
