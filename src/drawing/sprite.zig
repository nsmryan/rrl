const std = @import("std");
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const Str = utils.intern.Str;
const Intern = utils.intern.Intern;

const math = @import("math");
const Tween = math.tweening.Tween;

const Rect = math.rect.Rect;
const Dims = math.utils.Dims;

pub const FONT_WIDTH: i32 = 16;
pub const FONT_HEIGHT: i32 = 16;
pub const MAX_NAME_SIZE: usize = 64;

pub const SpriteIndex = u32;

pub const Sprite = struct {
    index: SpriteIndex,
    key: Str,
    flip_horiz: bool = false,
    flip_vert: bool = false,
    rotation: f64 = 0.0,

    pub fn init(index: SpriteIndex, key: Str) Sprite {
        return Sprite{ .index = index, .key = key };
    }

    pub fn fromKey(key: Str) Sprite {
        return Sprite.init(0, key);
    }

    pub fn withFlip(index: SpriteIndex, key: Str, flip_horiz: bool, flip_vert: bool) Sprite {
        return Sprite{ .index = index, .key = key, .flip_horiz = flip_horiz, .flip_vert = flip_vert };
    }

    pub fn eql(sprite: Sprite, other: Sprite) bool {
        return sprite.key == other.key and sprite.flip_horiz == other.flip_horiz and sprite.flip_vert == other.flip_vert and sprite.rotation == other.rotation;
    }
};

pub const SpriteAnimation = struct {
    name: Str,
    sprite: Sprite,
    start_index: SpriteIndex,
    max_index: SpriteIndex,
    index: f32,
    speed: f32,
    looped: bool,

    pub fn init(name: Str, index: SpriteIndex, max_index: SpriteIndex, speed: f32) SpriteAnimation {
        const spr = Sprite{ .index = index, .key = name, .flip_horiz = false, .flip_vert = false, .rotation = 0.0 };
        return SpriteAnimation{ .name = name, .index = @intToFloat(f32, index), .start_index = index, .sprite = spr, .max_index = max_index, .speed = speed, .looped = false };
    }

    pub fn singleFrame(name: Str) SpriteAnimation {
        return SpriteAnimation.init(name, 0, 0, 0.0);
    }

    pub fn step(self: *SpriteAnimation, dt: f32) void {
        const index_range = self.max_index - self.start_index;
        const new_index = self.index + (dt * self.speed);

        self.looped = new_index > @intToFloat(f32, self.max_index);
        if (self.looped) {
            const left: f32 = new_index - @floor(new_index);
            self.index = @intToFloat(f32, self.start_index + (@floatToInt(u32, new_index) % index_range)) + left;
        } else {
            self.index = new_index;
        }

        self.sprite.index = @floatToInt(u32, self.index);
    }

    pub fn current(self: *const SpriteAnimation) Sprite {
        var spr = Sprite.withFlip(self.sprite.index, self.sprite.key, self.sprite.flip_horiz, self.sprite.flip_vert);
        spr.rotation = self.sprite.rotation;
        return spr;
    }
};

// NOTE consider an interned string for the name instead of a fixed size buffer
pub const SpriteSheet = struct {
    name: Str,
    num_sprites: usize,
    rows: usize,
    cols: usize,
    width: usize,
    height: usize,
    x_offset: u32,
    y_offset: u32,

    pub fn init(name: Str, num_sprites: usize, rows: usize, cols: usize, width: usize, height: usize, x_offset: u32, y_offset: u32) SpriteSheet {
        return SpriteSheet{ .name = name, .num_sprites = num_sprites, .rows = rows, .cols = cols, .width = width, .height = height, .x_offset = x_offset, .y_offset = y_offset };
    }

    pub fn withOffset(name: Str, x_offset: u32, y_offset: u32, width: usize, height: usize) SpriteSheet {
        const rows = height / @intCast(usize, FONT_HEIGHT);
        const cols = width / @intCast(usize, FONT_WIDTH);
        const num_sprites = cols * rows;

        return SpriteSheet{
            .name = name,
            .num_sprites = num_sprites,
            .rows = rows,
            .cols = cols,
            .width = width,
            .height = height,
            .x_offset = x_offset,
            .y_offset = y_offset,
        };
    }

    pub fn single(name: Str, width: usize, height: usize) SpriteSheet {
        const num_sprites = 1;
        const rows = 1;
        const cols = 1;
        const x_offset = 0;
        const y_offset = 0;

        return SpriteSheet{
            .name = name,
            .num_sprites = num_sprites,
            .rows = rows,
            .cols = cols,
            .width = width,
            .height = height,
            .x_offset = x_offset,
            .y_offset = y_offset,
        };
    }

    pub fn sprite(sheet: *const SpriteSheet) Sprite {
        return Sprite.init(0, sheet.name);
    }

    pub fn numCells(self: *const SpriteSheet) Dims {
        return Dims{ .width = self.cols, .height = self.rows };
    }

    pub fn numPixels(self: *const SpriteSheet) Dims {
        return Dims.init(self.width, self.height);
    }

    pub fn spriteDims(self: *const SpriteSheet) Dims {
        const cell_dims = self.numCells();
        return Dims.init(self.width / cell_dims.width, self.height / cell_dims.height);
    }

    // Get the source rectangle for a particular sprite given by its index into the sprite sheet.
    pub fn spriteSrc(self: *const SpriteSheet, origIndex: u32) Rect {
        const cell_dims = self.numCells();
        const index = @intCast(usize, origIndex);
        const sprite_x = index % cell_dims.width;
        const sprite_y = index / cell_dims.width;

        const sprite_dims = self.spriteDims();
        //const sprite_width = cell_dims.width;
        //const sprite_height = cell_dims.height;

        const x = self.x_offset + sprite_x * sprite_dims.width;
        const y = self.y_offset + sprite_y * sprite_dims.height;
        const w = sprite_dims.width;
        const h = sprite_dims.height;
        const src = Rect{ .x_offset = x, .y_offset = y, .width = w, .height = h };

        return src;
    }
};

const ParseAtlasError = error{
    MissingField,
};

pub fn parseAtlasFile(atlas_file: []const u8, strings: *Intern, allocator: Allocator) !AutoHashMap(Str, SpriteSheet) {
    var file = try std.fs.cwd().openFile(atlas_file, .{});
    defer file.close();

    var sheets = AutoHashMap(Str, SpriteSheet).init(allocator);
    errdefer sheets.deinit();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = std.mem.split(u8, line, " ");

        const sprite_name = parts.next() orelse return ParseAtlasError.MissingField;
        const sprite_str = try strings.insert(sprite_name);

        const x = try std.fmt.parseInt(u32, parts.next() orelse return ParseAtlasError.MissingField, 10);
        const y = try std.fmt.parseInt(u32, parts.next() orelse return ParseAtlasError.MissingField, 10);
        const width = try std.fmt.parseInt(usize, parts.next() orelse return ParseAtlasError.MissingField, 10);
        const height = try std.fmt.parseInt(usize, parts.next() orelse return ParseAtlasError.MissingField, 10);

        var sheet = SpriteSheet.withOffset(sprite_str, x, y, width, height);

        // Button sprites are handled specially - they are always a single large sprite.
        // Button names are of the form "X_Button_Y"
        if (std.mem.startsWith(u8, sprite_name[2..], "Button")) {
            sheet.rows = 1;
            sheet.cols = 1;
            sheet.num_sprites = 1;
        }

        try sheets.put(sprite_str, sheet);
    }

    return sheets;
}

const SpriteLookupError = error{
    SpriteNameNotFound,
};
