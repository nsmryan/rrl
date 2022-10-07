const std = @import("std");
const assert = @import("std").debug.assert;

const area = @import("area.zig");
const Area = area.Area;
const Dims = area.Dims;
const utils = @import("utils.zig");
const Rect = utils.Rect;
const Pos = utils.Pos;

pub const Panel = struct {
    cells: Dims,
    num_pixels: Dims,

    pub fn init(num_pixels: Dims, cells: Dims) Panel {
        return Panel{
            .cells = cells,
            .num_pixels = num_pixels,
        };
    }

    pub fn cellDims(self: *const Panel) Dims {
        return Dims.init(self.num_pixels.width / self.cells.width, self.num_pixels.height / self.cells.height);
    }

    pub fn getArea(self: *const Panel) Area {
        return Area.init(@intCast(usize, self.cells.width), @intCast(usize, self.cells.height));
    }

    pub fn cellFromPixel(self: *const Panel, pixel: Pos) Pos {
        const dims = self.cellDims();
        return Pos.init(@intCast(i32, pixel.x / dims.width), @intCast(i32, pixel.y / dims.height));
    }

    pub fn pixelFromCell(self: *const Panel, cell: Pos) Pos {
        const dims = self.cellDims();
        return Pos.init(@intCast(i32, cell.x * dims.width), @intCast(i32, cell.y * dims.height));
    }

    pub fn getRectFull(self: *const Panel) Rect {
        return Rect{ .x = 0, .y = 0, .w = self.num_pixels.width, .h = self.num_pixels.height };
    }

    pub fn getRectUpLeft(self: *const Panel, width: usize, height: usize) Rect {
        assert(@intCast(u32, width) <= self.cells.width);
        assert(@intCast(u32, height) <= self.cells.height);

        const cell_dims = self.cellDims();

        const pixel_width = @intCast(u32, width) * cell_dims.width;
        const pixel_height = @intCast(u32, height) * cell_dims.height;

        return Rect{ .x = 0, .y = 0, .w = pixel_width, .h = pixel_height };
    }

    pub fn getRectFromArea(self: *const Panel, input_area: Area) Rect {
        const cell_dims = self.cellDims();

        const x_offset = @as(f32, input_area.x_offset) * @as(f32, cell_dims.width);
        const y_offset = @as(f32, input_area.y_offset) * @as(f32, cell_dims.height);

        const width = @as(u32, @as(f32, input_area.width) * @as(f32, cell_dims.width));
        const height = @as(u32, @as(f32, input_area.height) * @as(f32, cell_dims.height));

        // don't draw off the screen
        assert(@intCast(u32, x_offset) + width <= self.num_pixels.width);
        assert(@intCast(u32, y_offset) + height <= self.num_pixels.height);

        return Rect{ .x = @intCast(i32, x_offset), .y = @intCast(i32, y_offset), .w = width, .h = height };
    }

    pub fn getRectWithin(self: *const Panel, input_area: Area, target_dims: Dims) Rect {
        const base_rect = self.getRectFromArea(input_area);

        const scale_x = @as(f32, base_rect.w) / @as(f32, target_dims.width);
        const scale_y = @as(f32, base_rect.h) / @as(f32, target_dims.height);

        const scaler = undefined;
        if (scale_x * @as(f32, target_dims.height) > @as(f32, base_rect.rect.h)) {
            scaler = scale_y;
        } else {
            scaler = scale_x;
        }

        const final_target_width = @as(f32, target_dims.width) * scaler;
        const final_target_height = @as(f32, target_dims.height) * scaler;

        const x_inner_offset = (@as(f32, base_rect.w) - final_target_width) / 2.0;
        const y_inner_offset = (@as(f32, base_rect.h) - final_target_height) / 2.0;
        const x_offset = @intCast(i32, base_rect.x + x_inner_offset);
        const y_offset = @intCast(i32, base_rect.y + y_inner_offset);

        // check that we don't reach past the destination rect we should be drawing within
        assert((@as(f32, x_offset) + @as(f32, final_target_width)) <= @as(f32, base_rect.x) + @as(f32, base_rect.w));
        assert((@as(f32, y_offset) + @as(f32, final_target_height)) <= @as(f32, base_rect.y) + @as(f32, base_rect.h));

        return Rect(@intCast(i32, x_offset), @intCast(i32, y_offset), @intCast(u32, final_target_width), @intCast(u32, final_target_height));
    }
};
