const std = @import("std");

const assert = @import("std").debug.assert;

const utils = @import("utils.zig");
const Pos = @import("pos.zig").Pos;
const Dims = utils.Dims;

pub const RectSplit = struct {
    first: Rect,
    second: Rect,

    pub fn init(first: Rect, second: Rect) RectSplit {
        return RectSplit{ .first = first, .second = second };
    }
};

pub const Rect = struct {
    x_offset: usize = 0,
    y_offset: usize = 0,
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize) Rect {
        return Rect{ .width = width, .height = height };
    }

    pub fn initAt(x_offset: usize, y_offset: usize, width: usize, height: usize) Rect {
        return Rect{ .x_offset = x_offset, .y_offset = y_offset, .width = width, .height = height };
    }

    pub fn position(area: Rect) Pos {
        return Pos.init(@intCast(i32, area.x_offset), @intCast(i32, area.y_offset));
    }

    pub fn dims(self: *const Rect) Dims {
        return Dims.init(self.width, self.height);
    }

    pub fn splitLeft(self: *const Rect, left_width: usize) RectSplit {
        assert(left_width <= self.width);

        const right_width = self.width - left_width;
        const left = Rect.initAt(self.x_offset, self.y_offset, left_width, self.height);
        const right = Rect.initAt(self.x_offset + left_width, self.y_offset, right_width, self.height);

        return RectSplit.init(left, right);
    }

    pub fn splitRight(self: *const Rect, right_width: usize) RectSplit {
        assert(right_width <= self.width);

        const left_width = self.width - right_width;
        const left = Rect.initAt(self.x_offset, self.y_offset, left_width, self.height);
        const right = Rect.initAt(self.x_offset + left_width, self.y_offset, right_width, self.height);

        return RectSplit.init(left, right);
    }

    pub fn splitTop(self: *const Rect, top_height: usize) RectSplit {
        assert(top_height <= self.height);

        const top = Rect.initAt(self.x_offset, self.y_offset, self.width, top_height);
        const bottom = Rect.initAt(self.x_offset, self.y_offset + top_height, self.width, self.height - top_height);

        return RectSplit.init(top, bottom);
    }

    pub fn splitBottom(self: *const Rect, bottom_height: usize) RectSplit {
        assert(bottom_height <= self.height);

        const top_height = self.height - bottom_height;
        const top = Rect.initAt(self.x_offset, self.y_offset, self.width, top_height);
        const bottom = Rect.initAt(self.x_offset, self.y_offset + top_height, self.width, bottom_height);

        return RectSplit.init(top, bottom);
    }

    pub fn centered(self: *const Rect, width: usize, height: usize) Rect {
        assert(width <= self.width);
        assert(height <= self.height);

        const x_offset = (self.width - width) / 2;
        const y_offset = (self.height - height) / 2;

        return Rect.initAt(x_offset, y_offset, width, height);
    }

    pub fn cellAtPixel(self: *const Rect, pixel_pos: Pos) ?Pos {
        const cell_pos = Pos.init(@intCast(i32, pixel_pos.x / self.width), @intCast(i32, pixel_pos.y / self.height));

        return self.cellAt(cell_pos);
    }

    pub fn cellAt(self: *const Rect, cell_pos: Pos) ?Pos {
        if (@intCast(usize, cell_pos.x) >= self.x_offset and @intCast(usize, cell_pos.x) < self.x_offset + self.width and
            @intCast(usize, cell_pos.y) >= self.y_offset and @intCast(usize, cell_pos.y) < self.y_offset + self.height)
        {
            return Pos.init(@intCast(usize, cell_pos.x) - self.x_offset, @intCast(usize, cell_pos.y) - self.y_offset);
        }

        return null;
    }

    pub fn fitWithin(target: Rect, source: Rect) Rect {
        const x_scale = @intToFloat(f32, target.width) / @intToFloat(f32, source.width);
        const y_scale = @intToFloat(f32, target.height) / @intToFloat(f32, source.height);
        const scale = std.math.min(x_scale, y_scale);

        const width = @floatToInt(i32, @intToFloat(f32, source.width) * scale);
        const height = @floatToInt(i32, @intToFloat(f32, source.height) * scale);

        const x = target.x + @divFloor((target.width - width), @as(c_int, 2));
        const y = target.y + @divFloor((target.height - height), @as(c_int, 2));

        return Rect.init(x, y, width, height);
    }
};
