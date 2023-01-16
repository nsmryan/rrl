const assert = @import("std").debug.assert;

const math = @import("math");
const utils = math.utils;
const Pos = math.Pos;
const Dims = utils.Dims;

pub const AreaSplit = struct {
    first: Area,
    second: Area,

    pub fn init(first: Area, second: Area) AreaSplit {
        return AreaSplit{ .first = first, .second = second };
    }
};

pub const Area = struct {
    x_offset: usize = 0,
    y_offset: usize = 0,
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize) Area {
        return Area{ .width = width, .height = height };
    }

    pub fn initAt(x_offset: usize, y_offset: usize, width: usize, height: usize) Area {
        return Area{ .x_offset = x_offset, .y_offset = y_offset, .width = width, .height = height };
    }

    pub fn dims(self: *const Area) Dims {
        return Dims.init(self.width, self.height);
    }

    pub fn splitLeft(self: *const Area, left_width: usize) AreaSplit {
        assert(left_width <= self.width);

        const right_width = self.width - left_width;
        const left = Area.initAt(self.x_offset, self.y_offset, left_width, self.height);
        const right = Area.initAt(self.x_offset + left_width, self.y_offset, right_width, self.height);

        return AreaSplit.init(left, right);
    }

    pub fn splitRight(self: *const Area, right_width: usize) AreaSplit {
        assert(right_width <= self.width);

        const left_width = self.width - right_width;
        const left = Area.initAt(self.x_offset, self.y_offset, left_width, self.height);
        const right = Area.initAt(self.x_offset + left_width, self.y_offset, right_width, self.height);

        return AreaSplit.init(left, right);
    }

    pub fn splitTop(self: *const Area, top_height: usize) AreaSplit {
        assert(top_height <= self.height);

        const top = Area.initAt(self.x_offset, self.y_offset, self.width, top_height);
        const bottom = Area.initAt(self.x_offset, self.y_offset + top_height, self.width, self.height - top_height);

        return AreaSplit.init(top, bottom);
    }

    pub fn splitBottom(self: *const Area, bottom_height: usize) AreaSplit {
        assert(bottom_height <= self.height);

        const top_height = self.height - bottom_height;
        const top = Area.initAt(self.x_offset, self.y_offset, self.width, top_height);
        const bottom = Area.initAt(self.x_offset, self.y_offset + top_height, self.width, bottom_height);

        return AreaSplit.init(top, bottom);
    }

    pub fn centered(self: *const Area, width: usize, height: usize) Area {
        assert(width <= self.width);
        assert(height <= self.height);

        const x_offset = (self.width - width) / 2;
        const y_offset = (self.height - height) / 2;

        return Area.initAt(x_offset, y_offset, width, height);
    }

    pub fn cellAtPixel(self: *const Area, pixel_pos: Pos) ?Pos {
        const cell_pos = Pos.init(@intCast(i32, pixel_pos.x / self.width), @intCast(i32, pixel_pos.y / self.height));

        return self.cellAt(cell_pos);
    }

    pub fn cellAt(self: *const Area, cell_pos: Pos) ?Pos {
        if (@intCast(usize, cell_pos.x) >= self.x_offset and @intCast(usize, cell_pos.x) < self.x_offset + self.width and
            @intCast(usize, cell_pos.y) >= self.y_offset and @intCast(usize, cell_pos.y) < self.y_offset + self.height)
        {
            return Pos.init(@intCast(usize, cell_pos.x) - self.x_offset, @intCast(usize, cell_pos.y) - self.y_offset);
        }

        return null;
    }
};
