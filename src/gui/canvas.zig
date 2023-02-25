const std = @import("std");
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;

const sdl2 = @import("sdl2.zig");
const Texture = sdl2.SDL_Texture;
const Renderer = sdl2.SDL_Renderer;
const Font = sdl2.TTF_Font;

const drawing = @import("drawing");
const sprite = drawing.sprite;
const pnl = drawing.panel;
const Panel = pnl.Panel;
const DrawCmd = drawing.drawcmd.DrawCmd;
const Sprite = sprite.Sprite;
const SpriteSheet = sprite.SpriteSheet;

const utils = @import("utils");
const Str = utils.intern.Str;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;
const Rect = math.rect.Rect;

pub const Canvas = struct {
    panel: *Panel,
    renderer: *Renderer,
    target: *Texture,
    sprites: *Sprites,
    ascii_texture: AsciiTexture,

    pub fn init(panel: *Panel, renderer: *Renderer, target: *Texture, sprites: *Sprites, ascii_texture: AsciiTexture) Canvas {
        return Canvas{ .panel = panel, .renderer = renderer, .target = target, .sprites = sprites, .ascii_texture = ascii_texture };
    }

    pub fn draw(canvas: *Canvas, draw_cmd: *const DrawCmd) void {
        processDrawCmd(canvas.panel, canvas.renderer, canvas.target, canvas.sprites, canvas.ascii_texture, draw_cmd);
    }
};

pub const AsciiTexture = struct {
    texture: *Texture,
    num_chars: usize,
    width: u32,
    height: u32,
    char_width: u32,
    char_height: u32,

    pub fn init(texture: *Texture, num_chars: usize, width: u32, height: u32, char_width: u32, char_height: u32) AsciiTexture {
        return AsciiTexture{ .texture = texture, .num_chars = num_chars, .width = width, .height = height, .char_width = char_width, .char_height = char_height };
    }

    pub fn deinit(self: *AsciiTexture) void {
        sdl2.SDL_DestroyTexture(self.texture);
    }

    pub fn renderAsciiCharacters(renderer: *Renderer, font: *Font) !AsciiTexture {
        sdl2.TTF_SetFontStyle(font, sdl2.TTF_STYLE_BOLD);

        var chrs: [256]u8 = undefined;
        var chr_index: usize = 0;
        while (chr_index < 256) : (chr_index += 1) {
            chrs[chr_index] = @intCast(u8, chr_index);
        }
        chrs[math.utils.ASCII_END + 1] = 0;

        var text_surface = sdl2.TTF_RenderUTF8_Blended(font, chrs[math.utils.ASCII_START..math.utils.ASCII_END], makeColor(255, 255, 255, 255));
        defer sdl2.SDL_FreeSurface(text_surface);

        var font_texture = sdl2.SDL_CreateTextureFromSurface(renderer, text_surface) orelse {
            sdl2.SDL_Log("Unable to create sprite texture: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        var format: u32 = undefined;
        var access: c_int = undefined;
        var w: c_int = undefined;
        var h: c_int = undefined;
        _ = sdl2.SDL_QueryTexture(font_texture, &format, &access, &w, &h);

        const ascii_width = math.utils.ASCII_END - math.utils.ASCII_START;
        const ascii_texture = AsciiTexture.init(
            font_texture,
            ascii_width,
            @intCast(u32, w),
            @intCast(u32, h),
            @divFloor(@intCast(u32, w), @intCast(u32, ascii_width)),
            @intCast(u32, h),
        );

        return ascii_texture;
    }
};

pub const Sprites = struct {
    texture: *Texture,
    sheets: AutoHashMap(Str, SpriteSheet),

    pub fn init(texture: *Texture, sheets: AutoHashMap(Str, SpriteSheet)) Sprites {
        return Sprites{ .texture = texture, .sheets = sheets };
    }

    pub fn deinit(sprites: *Sprites) void {
        sdl2.SDL_DestroyTexture(sprites.texture);
        sprites.sheets.deinit();
    }

    pub fn fromKey(sprites: *const Sprites, str: Str) SpriteSheet {
        return sprites.sheets.get(str).?;
    }
};

pub fn processDrawCmd(panel: *Panel, renderer: *Renderer, texture: *Texture, sprites: *Sprites, ascii_texture: AsciiTexture, draw_cmd: *const DrawCmd) void {
    var canvas = Canvas.init(panel, renderer, texture, sprites, ascii_texture);
    switch (draw_cmd.*) {
        .sprite => |params| processSpriteCmd(canvas, params),

        .spriteScaled => |params| _ = processSpriteScale(canvas, params),

        .spriteFloat => |params| _ = processSpriteFloat(canvas, params),

        .highlightTile => |params| _ = processHighlightTile(canvas, params),

        .outlineTile => |params| _ = processOutlineTile(canvas, params),

        .text => |params| _ = processText(canvas, params),

        .textFloat => |params| _ = processTextFloat(canvas, params),

        .textJustify => |params| _ = processTextJustify(canvas, params),

        .rect => |params| _ = processRectCmd(canvas, params),

        .rectFloat => |params| _ = processRectFloatCmd(canvas, params),

        .fill => |params| processFillCmd(canvas, params),
    }
}

pub fn processTextGeneric(canvas: Canvas, text: [64]u8, len: usize, color: Color, pixel_pos: Pos, scale: f32) void {
    const ascii_width = math.utils.ASCII_END - math.utils.ASCII_START;

    const cell_dims = canvas.panel.cellDims();

    const font_width = @intCast(usize, canvas.ascii_texture.width) / ascii_width;
    const font_height = @intCast(usize, canvas.ascii_texture.height);

    const char_height = @floatToInt(u32, @intToFloat(f32, cell_dims.height) * scale);
    const char_width_unscaled = (cell_dims.height * font_width) / font_height;
    const char_width = @floatToInt(u32, @intToFloat(f32, char_width_unscaled) * scale);

    _ = sdl2.SDL_SetTextureBlendMode(canvas.target, sdl2.SDL_BLENDMODE_BLEND);

    //_ = sdl2.SDL_SetTextureColorMod(canvas.sprites.texture, color.r, color.g, color.b);
    _ = sdl2.SDL_SetTextureAlphaMod(canvas.sprites.texture, color.a);

    _ = sdl2.SDL_SetTextureColorMod(canvas.ascii_texture.texture, color.r, color.g, color.b);
    _ = sdl2.SDL_SetTextureAlphaMod(canvas.ascii_texture.texture, color.a);

    const y_offset = pixel_pos.y;
    var x_offset = pixel_pos.x;
    for (text[0..len]) |chr| {
        if (chr == 0) {
            break;
        }

        const chr_num = std.ascii.toLower(chr);
        const chr_index = @intCast(i32, chr_num) - @intCast(i32, math.utils.ASCII_START);

        const src_rect = Rect.initAt(font_width * @intCast(usize, chr_index), 0, @intCast(u32, font_width), @intCast(u32, font_height));

        const dst_pos = Pos.init(x_offset, y_offset);
        const dst_rect = Rect.initAt(
            @intCast(usize, dst_pos.x),
            @intCast(usize, dst_pos.y),
            @intCast(u32, char_width),
            @intCast(u32, char_height),
        );

        _ = sdl2.SDL_RenderCopyEx(canvas.renderer, canvas.ascii_texture.texture, &Sdl2Rect(src_rect), &Sdl2Rect(dst_rect), 0.0, null, 0);
        x_offset += @intCast(i32, char_width);
    }
}

pub fn processTextJustify(canvas: Canvas, params: drawing.drawcmd.DrawTextJustify) void {
    const cell_dims = canvas.panel.cellDims();

    const char_width_unscaled = (cell_dims.height * canvas.ascii_texture.char_width) / canvas.ascii_texture.char_height;
    const char_width = @floatToInt(usize, @intToFloat(f32, char_width_unscaled) * params.scale);

    //const char_height_unscaled = (cell_dims.height * canvas.ascii_texture.char_width) / canvas.ascii_texture.char_height;
    //const char_height = @floatToInt(u32, @intToFloat(f32, char_width_unscaled) * params.scale);
    const char_height = @floatToInt(usize, @intToFloat(f32, cell_dims.height) * params.scale);

    const pixel_width = params.width * cell_dims.width;

    var x_offset: usize = undefined;
    switch (params.justify) {
        .right => {
            x_offset = (@intCast(usize, params.pos.x) * cell_dims.width) + pixel_width - char_width * params.len;
        },

        .center => {
            x_offset = (@intCast(usize, params.pos.x) * cell_dims.width) + @divFloor(pixel_width, 2) - @divFloor(char_width * params.len, 2);
        },

        .left => {
            x_offset = @intCast(usize, params.pos.x) * cell_dims.width;
        },
    }

    const y_offset = @intCast(usize, params.pos.y) * cell_dims.height;

    const rect = Rect.initAt(x_offset, y_offset, @intCast(usize, params.len * char_width), char_height);

    _ = sdl2.SDL_SetTextureBlendMode(canvas.target, sdl2.SDL_BLENDMODE_BLEND);

    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, 0, 0, 0, 255);
    _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(rect));

    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.bg_color.r, params.bg_color.g, params.bg_color.b, params.bg_color.a);
    _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(rect));

    const x = @intCast(i32, x_offset);
    const y = @intCast(i32, y_offset);
    processTextGeneric(canvas, params.text, params.len, params.color, Pos.init(x, y), params.scale);
}

pub fn processTextFloat(canvas: Canvas, params: drawing.drawcmd.DrawTextFloat) void {
    const cell_dims = canvas.panel.cellDims();

    const char_width_unscaled = (cell_dims.height * canvas.ascii_texture.char_width) / canvas.ascii_texture.char_height;
    const char_width = @floatToInt(u32, @intToFloat(f32, char_width_unscaled) * params.scale);
    const text_pixel_width = @intCast(i32, params.len) * @intCast(i32, char_width);

    const x_offset = @floatToInt(i32, params.x * @intToFloat(f32, cell_dims.width)) - @divFloor(text_pixel_width, 2);
    const y_offset = @floatToInt(i32, params.y * @intToFloat(f32, cell_dims.height));
    processTextGeneric(canvas, params.text, params.len, params.color, Pos.init(x_offset, y_offset), params.scale);
}

pub fn processText(canvas: Canvas, params: drawing.drawcmd.DrawText) void {
    const cell_dims = canvas.panel.cellDims();

    const x_offset = params.pos.x * @intCast(i32, cell_dims.width);
    const y_offset = params.pos.y * @intCast(i32, cell_dims.height);

    processTextGeneric(canvas, params.text, params.len, params.color, Pos.init(x_offset, y_offset), params.scale);
}

pub fn processSpriteFloat(canvas: Canvas, params: drawing.drawcmd.DrawSpriteFloat) void {
    const sprite_sheet = &canvas.sprites.sheets.get(params.sprite.key).?;

    const cell_dims = canvas.panel.cellDims();

    const src_rect = sprite_sheet.spriteSrc(params.sprite.index);

    const x_offset = @floatToInt(usize, params.x * @intToFloat(f32, cell_dims.width));
    const y_offset = @floatToInt(usize, params.y * @intToFloat(f32, cell_dims.height));

    const dst_rect = Rect.initAt(
        x_offset,
        y_offset,
        @floatToInt(usize, @intToFloat(f32, cell_dims.width) * params.x_scale),
        @floatToInt(usize, @intToFloat(f32, cell_dims.height) * params.y_scale),
    );

    _ = sdl2.SDL_SetTextureBlendMode(canvas.target, sdl2.SDL_BLENDMODE_BLEND);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureColorMod(canvas.sprites.texture, params.color.r, params.color.g, params.color.b);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureAlphaMod(canvas.sprites.texture, params.color.a);

    _ = sdl2.SDL_RenderCopyEx(
        canvas.renderer,
        canvas.sprites.texture,
        &Sdl2Rect(src_rect),
        &Sdl2Rect(dst_rect),
        params.sprite.rotation,
        null,
        flipFlags(&params.sprite),
    );
}

pub fn processSpriteScale(canvas: Canvas, params: drawing.drawcmd.DrawSpriteScaled) void {
    const cell_dims = canvas.panel.cellDims();
    const sprite_sheet = &canvas.sprites.sheets.get(params.sprite.key).?;

    const src_rect = sprite_sheet.spriteSrc(params.sprite.index);

    const dst_width = @floatToInt(u32, @intToFloat(f32, cell_dims.width) * params.scale);
    const dst_height = @floatToInt(u32, @intToFloat(f32, cell_dims.height) * params.scale);

    // Mod by the dimensions of the cell to find the margin with the cell or within the last cell if
    // scale > 1.0.
    const x_margin = (cell_dims.width - (dst_width % cell_dims.width)) / 2;
    const y_margin = (cell_dims.height - (dst_height % cell_dims.height)) / 2;

    var dst_x = @intCast(usize, params.pos.x) * cell_dims.width;
    var dst_y = @intCast(usize, params.pos.y) * cell_dims.height;

    switch (params.dir) {
        .center => {
            dst_x += x_margin;
            dst_y += y_margin;
        },

        .left => {
            dst_y += y_margin;
        },

        .right => {
            dst_x += cell_dims.width - dst_width;
            dst_y += y_margin;
        },

        .up => {
            dst_x += x_margin;
        },

        .down => {
            dst_x += x_margin;
            dst_y += cell_dims.height - dst_height;
        },

        .downLeft => {
            dst_y += cell_dims.height - dst_height;
        },

        .downRight => {
            dst_x += cell_dims.width - dst_width;
            dst_y += cell_dims.height - dst_height;
        },

        .upLeft => {
            // Already in the upper left corner by default.
        },

        .upRight => {
            dst_x += cell_dims.width - dst_width;
        },
    }

    const dst_rect = Rect.initAt(dst_x, dst_y, dst_width, dst_height);

    _ = sdl2.SDL_SetTextureBlendMode(canvas.target, sdl2.SDL_BLENDMODE_BLEND);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureColorMod(canvas.sprites.texture, params.color.r, params.color.g, params.color.b);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureAlphaMod(canvas.sprites.texture, params.color.a);

    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_RenderCopyEx(
        canvas.renderer,
        canvas.sprites.texture,
        &Sdl2Rect(src_rect),
        &Sdl2Rect(dst_rect),
        params.sprite.rotation,
        null,
        flipFlags(&params.sprite),
    );
}

pub fn processHighlightTile(canvas: Canvas, params: drawing.drawcmd.DrawHighlightTile) void {
    const cell_dims = canvas.panel.cellDims();

    _ = sdl2.SDL_SetRenderDrawBlendMode(canvas.renderer, sdl2.SDL_BLENDMODE_BLEND);
    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.color.r, params.color.g, params.color.b, params.color.a);

    // Ignore negative indices.
    if (params.pos.x < 0 or params.pos.y < 0) {
        return;
    }

    const rect = Rect.initAt(
        @intCast(usize, params.pos.x) * cell_dims.width,
        @intCast(usize, params.pos.y) * cell_dims.height,
        @intCast(u32, cell_dims.width),
        @intCast(u32, cell_dims.height),
    );

    _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(rect));
}

pub fn processOutlineTile(canvas: Canvas, params: drawing.drawcmd.DrawOutlineTile) void {
    const cell_dims = canvas.panel.cellDims();

    _ = sdl2.SDL_SetRenderDrawBlendMode(canvas.renderer, sdl2.SDL_BLENDMODE_BLEND);
    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.color.r, params.color.g, params.color.b, params.color.a);

    const rect = Rect.initAt(
        @intCast(usize, params.pos.x) * cell_dims.width + 1,
        @intCast(usize, params.pos.y) * cell_dims.height + 1,
        @intCast(u32, cell_dims.width),
        @intCast(u32, cell_dims.height),
    );

    _ = sdl2.SDL_RenderDrawRect(canvas.renderer, &Sdl2Rect(rect));
}

pub fn processFillCmd(canvas: Canvas, params: drawing.drawcmd.DrawFill) void {
    const cell_dims = canvas.panel.cellDims();
    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.color.r, params.color.g, params.color.b, params.color.a);
    var src_rect = Rect.initAt(@intCast(usize, params.pos.x) * cell_dims.width, @intCast(usize, params.pos.y) * cell_dims.height, @intCast(u32, cell_dims.width), @intCast(u32, cell_dims.height));
    var sdl2_rect = Sdl2Rect(src_rect);
    _ = sdl2.SDL_RenderFillRect(canvas.renderer, &sdl2_rect);
}

pub fn processRectCmd(canvas: Canvas, params: drawing.drawcmd.DrawRect) void {
    assert(params.offset_percent < 1.0);

    const cell_dims = canvas.panel.cellDims();

    _ = sdl2.SDL_SetRenderDrawBlendMode(canvas.renderer, sdl2.SDL_BLENDMODE_BLEND);
    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.color.r, params.color.g, params.color.b, params.color.a);

    const offset_x = @floatToInt(usize, @intToFloat(f32, cell_dims.width) * params.offset_percent);
    const x: usize = @intCast(usize, cell_dims.width) * @intCast(usize, params.pos.x) + offset_x;

    const offset_y = @floatToInt(usize, @intToFloat(f32, cell_dims.height) * params.offset_percent);
    const y: usize = @intCast(usize, cell_dims.height) * @intCast(usize, params.pos.y) + offset_y;

    const width = @intCast(u32, cell_dims.width * params.width - (2 * @intCast(u32, offset_x)));
    const height = @intCast(u32, cell_dims.height * params.height - (2 * @intCast(u32, offset_y)));

    if (params.filled) {
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x, y, width, height)));
    } else {
        const size = @intCast(u32, (canvas.panel.num_pixels.width / canvas.panel.cells.width) / 10);
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x, y, size, height)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x, y, width, size)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x + width, y, size, height + size)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x, y + height, width + size, size)));
    }
}

pub fn processRectFloatCmd(canvas: Canvas, params: drawing.drawcmd.DrawRectFloat) void {
    const cell_dims = canvas.panel.cellDims();

    _ = sdl2.SDL_SetRenderDrawColor(canvas.renderer, params.color.r, params.color.g, params.color.b, params.color.a);

    const x_offset = @floatToInt(usize, params.x * @intToFloat(f32, cell_dims.width));
    const y_offset = @floatToInt(usize, params.y * @intToFloat(f32, cell_dims.height));

    const width = @floatToInt(u32, params.width * @intToFloat(f32, cell_dims.width));
    const height = @floatToInt(u32, params.height * @intToFloat(f32, cell_dims.height));

    const size = @intCast(u32, (canvas.panel.num_pixels.width / canvas.panel.cells.width) / 5);
    if (params.filled) {
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x_offset, y_offset, width, height)));
    } else {
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x_offset, y_offset, size, height)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x_offset, y_offset, width + size, size)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x_offset + width, y_offset, size, height)));
        _ = sdl2.SDL_RenderFillRect(canvas.renderer, &Sdl2Rect(Rect.initAt(x_offset, y_offset + height - size, width + size, size)));
    }
}

pub fn processSpriteCmd(canvas: Canvas, params: drawing.drawcmd.DrawSprite) void {
    const sprite_sheet = &canvas.sprites.sheets.get(params.sprite.key).?;
    const cell_dims = canvas.panel.cellDims();

    const x = params.pos.x * @intCast(i32, cell_dims.width);
    const y = params.pos.y * @intCast(i32, cell_dims.height);
    const pos = Pos.init(x, y);

    // Negative positions are accepted, but not drawn.
    if (pos.x < 0 or pos.y < 0) {
        return;
    }

    const dst_rect = Rect.initAt(@intCast(usize, pos.x), @intCast(usize, pos.y), @intCast(u32, cell_dims.width), @intCast(u32, cell_dims.height));

    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureBlendMode(canvas.target, sdl2.SDL_BLENDMODE_BLEND);

    const src_rect = sprite_sheet.spriteSrc(params.sprite.index);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureColorMod(canvas.sprites.texture, params.color.r, params.color.g, params.color.b);
    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_SetTextureAlphaMod(canvas.sprites.texture, params.color.a);

    // NOTE(error) ignoring error return.
    _ = sdl2.SDL_RenderCopyEx(
        canvas.renderer,
        canvas.sprites.texture,
        &Sdl2Rect(src_rect),
        &Sdl2Rect(dst_rect),
        params.sprite.rotation,
        null,
        flipFlags(&params.sprite),
    );
}

pub fn flipFlags(spr: *const Sprite) sdl2.SDL_RendererFlip {
    var flags: sdl2.SDL_RendererFlip = 0;

    if (spr.flip_horiz) {
        flags |= sdl2.SDL_FLIP_HORIZONTAL;
    }

    if (spr.flip_vert) {
        flags |= sdl2.SDL_FLIP_VERTICAL;
    }

    return flags;
}

pub fn Sdl2Color(color: Color) sdl2.SDL_Color {
    return sdl2.SDL_Color{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

pub fn Sdl2Rect(rect: Rect) sdl2.SDL_Rect {
    return sdl2.SDL_Rect{
        .x = @intCast(c_int, rect.x_offset),
        .y = @intCast(c_int, rect.y_offset),
        .w = @intCast(c_int, rect.width),
        .h = @intCast(c_int, rect.height),
    };
}

pub fn makeColor(r: u8, g: u8, b: u8, a: u8) sdl2.SDL_Color {
    return sdl2.SDL_Color{ .r = r, .g = g, .b = b, .a = a };
}
