const std = @import("std");

const Sprite = @import("sprite.zig").Sprite;
const utils = @import("utils.zig");
const Color = utils.Color;
const Pos = utils.Pos;
const Direction = utils.Direction;

pub const Justify = enum {
    right,
    center,
    left,
};

pub const DrawSprite = struct { sprite: Sprite, color: Color, pos: Pos };
pub const DrawSpriteScaled = struct { sprite: Sprite, scale: f32, dir: Direction, color: Color, pos: Pos };
pub const DrawSpriteFloat = struct { sprite: Sprite, color: Color, x: f32, y: f32, x_scale: f32, y_scale: f32 };
pub const DrawHighlightTile = struct { color: Color, pos: Pos };
pub const DrawOutlineTile = struct { color: Color, pos: Pos };
pub const DrawText = struct { text: [64]u8 = [1]u8{0} ** 64, len: usize, color: Color, pos: Pos, scale: f32 };
pub const DrawTextFloat = struct { text: [64]u8 = [1]u8{0} ** 64, len: usize, color: Color, x: f32, y: f32, scale: f32 };
pub const DrawTextJustify = struct { text: [64]u8 = [1]u8{0} ** 64, len: usize, justify: Justify, color: Color, pos: Pos, width: u32, scale: f32 };
pub const DrawRect = struct { pos: Pos, width: u32, height: u32, offset_percent: f32, filled: bool, color: Color };
pub const DrawRectFloat = struct { x: f32, y: f32, width: f32, height: f32, filled: bool, color: Color };
pub const DrawFill = struct { pos: Pos, color: Color };

pub const DrawCmd = union(enum) {
    sprite: DrawSprite,
    spriteScaled: DrawSpriteScaled,
    spriteFloat: DrawSpriteFloat,
    highlightTile: DrawHighlightTile,
    outlineTile: DrawOutlineTile,
    text: DrawText,
    textFloat: DrawTextFloat,
    textJustify: DrawTextJustify,
    rect: DrawRect,
    rectFloat: DrawRectFloat,
    fill: DrawFill,

    pub fn aligned(self: *DrawCmd) bool {
        return self.* != .spriteFloat and self.* != .textFloat;
    }

    // NOTE(zig) I would be surprised if this worked. Instead, maybe dispatch on type and use "@field"?
    pub fn pos(self: *DrawCmd) Pos {
        switch (self.*) {
            .sprite => |draw_cmd| return draw_cmd.pos,
            .spriteScaled => |draw_cmd| return draw_cmd.pos,
            .highlightTile => |draw_cmd| return draw_cmd.pos,
            .outlineTile => |draw_cmd| return draw_cmd.pos,
            .text => |draw_cmd| return draw_cmd.pos,
            .textJustify => |draw_cmd| return draw_cmd.pos,
            .rect => |draw_cmd| return draw_cmd.pos,
            .fill => |draw_cmd| return draw_cmd.pos,
            .spriteFloat => |draw_cmd| return Pos.init(@floatToInt(i32, draw_cmd.x), @floatToInt(i32, draw_cmd.y)),
            .textFloat => |draw_cmd| return Pos.init(@floatToInt(i32, draw_cmd.x), @floatToInt(i32, draw_cmd.y)),
            .rectFloat => |draw_cmd| return Pos.init(@floatToInt(i32, draw_cmd.x), @floatToInt(i32, draw_cmd.y)),
        }
    }

    pub fn sprite(spr: Sprite, color: Color, position: Pos) DrawCmd {
        return DrawCmd{ .sprite = DrawSprite{ .sprite = spr, .color = color, .pos = position } };
    }

    pub fn spriteScaled(spr: Sprite, scale: f32, dir: Direction, color: Color, position: Pos) DrawCmd {
        return DrawCmd{ .spriteScaled = DrawSpriteScaled{ .sprite = spr, .scale = scale, .dir = dir, .color = color, .pos = position } };
    }

    pub fn spriteFloat(spr: Sprite, color: Color, x: f32, y: f32, x_scale: f32, y_scale: f32) DrawCmd {
        return DrawCmd{ .spriteFloat = DrawSpriteFloat{ .sprite = spr, .color = color, .x = x, .y = y, .x_scale = x_scale, .y_scale = y_scale } };
    }

    pub fn highlightTile(position: Pos, color: Color) DrawCmd {
        return DrawCmd{ .highlightTile = DrawHighlightTile{ .pos = position, .color = color } };
        //return DrawCmd{ .rect = DrawRect{ .pos = position, .width = 1, .height = 1, .offset_percent = 0.0, .filled = true, .color = color } };
    }

    pub fn outlineTile(position: Pos, color: Color) DrawCmd {
        return DrawCmd{ .outlineTile = DrawOutlineTile{ .pos = position, .color = color } };
        //return DrawCmd{ .rect = DrawRect{ .pos = position, .width = 1, .height = 1, .offset_percent = 0.0, .filled = false, .color = color } };
    }

    pub fn text(txt: []const u8, position: Pos, color: Color, scale: f32) DrawCmd {
        var textCmd = DrawCmd{ .text = DrawText{ .len = txt.len, .pos = position, .color = color, .scale = scale } };
        std.mem.copy(u8, textCmd.text.text[0..txt.len], txt);
        return textCmd;
    }

    pub fn textFloat(txt: []const u8, x: f32, y: f32, color: Color, scale: f32) DrawCmd {
        var textCmd = DrawCmd{ .textFloat = DrawTextFloat{ .len = txt.len, .color = color, .x = x, .y = y, .scale = scale } };
        std.mem.copy(u8, textCmd.textFloat.text[0..txt.len], txt);
        return textCmd;
    }

    pub fn textJustify(txt: []const u8, justify: Justify, position: Pos, color: Color, width: u32, scale: f32) DrawCmd {
        var textCmd = DrawCmd{ .textJustify = DrawTextJustify{ .len = txt.len, .justify = justify, .color = color, .pos = position, .width = width, .scale = scale } };
        std.mem.copy(u8, textCmd.textJustify.text[0..txt.len], txt);
        return textCmd;
    }

    pub fn rect(position: Pos, width: u32, height: u32, offset_percent: f32, filled: bool, color: Color) DrawCmd {
        return DrawCmd{ .rect = DrawRect{ .pos = position, .width = width, .height = height, .offset_percent = offset_percent, .filled = filled, .color = color } };
    }

    pub fn rectFloat(x: f32, y: f32, width: f32, height: f32, filled: bool, color: Color) DrawCmd {
        return DrawCmd{ .rectFloat = DrawRectFloat{ .x = x, .y = y, .width = width, .height = height, .filled = filled, .color = color } };
    }

    pub fn fill(position: Pos, color: Color) DrawCmd {
        return DrawCmd{ .fill = DrawFill{ .pos = position, .color = color } };
    }
};
