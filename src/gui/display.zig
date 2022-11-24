const std = @import("std");
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const mem = std.mem;
const fs = std.fs;
const Allocator = mem.Allocator;

const sdl2 = @import("sdl2.zig");
const Texture = sdl2.SDL_Texture;
const Renderer = sdl2.SDL_Renderer;
const Font = sdl2.TTF_Font;
const Window = sdl2.SDL_Window;

const drawcmd = @import("drawcmd");
const panel = drawcmd.panel;
const area = drawcmd.area;
const Justify = drawcmd.drawcmd.Justify;
const sprite = drawcmd.sprite;
const SpriteAnimation = drawcmd.sprite.SpriteAnimation;
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Panel = panel.Panel;
const SpriteSheet = sprite.SpriteSheet;

const utils = @import("utils");
const Comp = utils.comp.Comp;
const intern = utils.intern;
const Str = utils.intern.Str;

const drawing = @import("drawing.zig");
const Sprites = drawing.Sprites;

const math = @import("math");
const Pos = math.pos.Pos;
const MoveDirection = math.direction.MoveDirection;
const Color = math.utils.Color;
const Dims = math.utils.Dims;

pub const Display = struct {
    window: *Window,
    renderer: *Renderer,
    font: *Font,
    ascii_texture: drawing.AsciiTexture,
    screen_texture: *Texture,
    sprites: Sprites,
    strings: intern.Intern,

    drawcmds: ArrayList(DrawCmd),
    allocator: Allocator,

    pub fn init(window_width: c_int, window_height: c_int, allocator: Allocator) !Display {
        var drawcmds = ArrayList(DrawCmd).init(allocator);

        if (sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO) != 0) {
            sdl2.SDL_Log("Unable to initialize SDL: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        }

        _ = sdl2.SDL_ShowCursor(0);

        if (sdl2.TTF_Init() == -1) {
            sdl2.SDL_Log("Unable to initialize SDL_ttf: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        }

        const window = sdl2.SDL_CreateWindow("DrawCmd", sdl2.SDL_WINDOWPOS_UNDEFINED, sdl2.SDL_WINDOWPOS_UNDEFINED, window_width, window_height, sdl2.SDL_WINDOW_OPENGL) orelse {
            sdl2.SDL_Log("Unable to create window: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        // If testing, do not bring up window.
        if (@import("builtin").is_test) {
            sdl2.SDL_HideWindow(window);
        }

        const renderer = sdl2.SDL_CreateRenderer(window, -1, sdl2.SDL_RENDERER_ACCELERATED) orelse {
            sdl2.SDL_Log("Unable to create renderer: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        const screen_texture = sdl2.SDL_CreateTexture(renderer, sdl2.SDL_PIXELFORMAT_RGBA8888, sdl2.SDL_TEXTUREACCESS_TARGET, window_width, window_height) orelse {
            sdl2.SDL_Log("Unable to create screen texture: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        // NOTE default to rendering to the screen. If we move to multiple targets, we may use this as a final
        // back buffer so we can save/restore/etc the screen buffer.
        //if (sdl2.SDL_SetRenderTarget(renderer, screen_texture) != 0) {
        //    sdl2.SDL_Log("Unable to set render target: %s", sdl2.SDL_GetError());
        //    return error.SDLInitializationFailed; //}

        var strings = intern.Intern.init(allocator);
        var sprites = try loadSprites("data/spriteAtlas.txt", "data/spriteAtlas.png\x00", &strings, renderer, allocator);

        const font = sdl2.TTF_OpenFont("data/Inconsolata-Bold.ttf", 20) orelse {
            sdl2.SDL_Log("Unable to create font from tff: %s", sdl2.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        const ascii_texture = try drawing.AsciiTexture.renderAsciiCharacters(renderer, font);

        var game: Display = Display{
            .window = window,
            .renderer = renderer,
            .font = font,
            .ascii_texture = ascii_texture,
            .sprites = sprites,
            .screen_texture = screen_texture,
            .strings = strings,
            .drawcmds = drawcmds,
            .allocator = allocator,
        };
        return game;
    }

    pub fn push(self: *Display, cmd: DrawCmd) !void {
        try self.drawcmds.append(cmd);
    }

    pub fn present(display: *Display, dims: Dims) void {
        _ = sdl2.SDL_SetRenderDrawColor(display.renderer, 0, 0, 0, sdl2.SDL_ALPHA_OPAQUE);
        _ = sdl2.SDL_RenderClear(display.renderer);

        var width: c_int = 0;
        var height: c_int = 0;
        sdl2.SDL_GetWindowSize(display.window, &width, &height);
        const num_pixels = Dims.init(@intCast(usize, width), @intCast(usize, height));
        var screen_panel = Panel.init(num_pixels, dims);

        for (display.drawcmds.items) |cmd| {
            drawing.processDrawCmd(&screen_panel, display.renderer, display.screen_texture, &display.sprites, display.ascii_texture, &cmd);
        }

        sdl2.SDL_RenderPresent(display.renderer);

        display.drawcmds.clearRetainingCapacity();
    }

    //fn renderText(self: *Display, text: []const u8, color: sdl2.SDL_Color) !*Texture {
    //    const c_text = @ptrCast([*c]const u8, text);
    //    const text_surface = sdl2.TTF_RenderText_Blended(self.font, c_text, color) orelse {
    //        sdl2.SDL_Log("Unable to create text from font: %s", sdl2.SDL_GetError());
    //        return error.SDLInitializationFailed;
    //    };

    //    const texture = sdl2.SDL_CreateTextureFromSurface(self.renderer, text_surface) orelse {
    //        sdl2.SDL_Log("Unable to create texture from surface: %s", sdl2.SDL_GetError());
    //        return error.SDLInitializationFailed;
    //    };

    //    return texture;
    //}

    pub fn deinit(self: *Display) void {
        self.ascii_texture.deinit();
        sdl2.SDL_DestroyTexture(self.screen_texture);
        sdl2.TTF_CloseFont(self.font);
        sdl2.SDL_DestroyRenderer(self.renderer);
        sdl2.SDL_DestroyWindow(self.window);
        sdl2.SDL_Quit();
        self.sprites.deinit();
        self.strings.deinit();
    }

    pub fn wait_for_frame(self: *Display) void {
        _ = self;
        sdl2.SDL_Delay(17);
    }

    pub fn handle_input(self: *Display) bool {
        _ = self;

        var quit = false;

        var event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                sdl2.SDL_QUIT => {
                    quit = true;
                },

                // SDL_Scancode scancode;      /**< SDL physical key code - see ::SDL_Scancode for details */
                // SDL_Keycode sym;            /**< SDL virtual key code - see ::SDL_Keycode for details */
                // Uint16 mod;                 /**< current key modifiers */
                sdl2.SDL_KEYDOWN => {
                    const code: i32 = event.key.keysym.sym;
                    const key: sdl2.SDL_KeyCode = @intCast(c_uint, code);

                    //const a_code = sdl2.SDLK_a;
                    //const z_code = sdl2.SDLK_z;

                    if (key == sdl2.SDLK_RETURN) {
                        sdl2.SDL_Log("Pressed enter");
                    } else if (key == sdl2.SDLK_ESCAPE) {
                        quit = true;
                    } else {
                        sdl2.SDL_Log("Pressed: %c", key);
                    }
                },

                sdl2.SDL_KEYUP => {},

                sdl2.SDL_MOUSEMOTION => {
                    //self.state.mouse = sdl2.SDL_Point{ .x = event.motion.x, .y = event.motion.y };
                },

                sdl2.SDL_MOUSEBUTTONDOWN => {},

                sdl2.SDL_MOUSEBUTTONUP => {},

                sdl2.SDL_MOUSEWHEEL => {},

                // just for fun...
                sdl2.SDL_DROPFILE => {
                    sdl2.SDL_Log("Dropped file '%s'", event.drop.file);
                },
                sdl2.SDL_DROPTEXT => {
                    sdl2.SDL_Log("Dropped text '%s'", event.drop.file);
                },
                sdl2.SDL_DROPBEGIN => {
                    sdl2.SDL_Log("Drop start");
                },
                sdl2.SDL_DROPCOMPLETE => {
                    sdl2.SDL_Log("Drop done");
                },

                // could be used for clock tick
                sdl2.SDL_USEREVENT => {},

                else => {},
            }
        }

        return quit;
    }

    pub fn animation(self: *Display, name: []const u8, speed: f32) !sprite.SpriteAnimation {
        const key = try self.lookupSpritekey(name);
        const num_sprites = try self.numSprites(name);
        return SpriteAnimation.init(key, 0, @intCast(u32, num_sprites), speed);
    }

    pub fn lookupSpritekey(self: *Display, name: []const u8) !Str {
        return self.strings.toKey(name);
    }

    pub fn numSprites(self: *Display, name: []const u8) !usize {
        const key = try self.lookupSpritekey(name);
        return self.sprites.sheets.get(key).?.num_sprites;
    }
};

fn loadSprites(atlas_text: []const u8, atlas_image: []const u8, strings: *intern.Intern, renderer: *Renderer, allocator: Allocator) !Sprites {
    // NOTE technically this cast isn't valid- the string is not necessarily null terminated since it starts as a slice.
    const sprite_surface = sdl2.IMG_Load(@ptrCast([*c]const u8, atlas_image.ptr)) orelse {
        sdl2.SDL_Log("Unable to load sprite image: %s", sdl2.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl2.SDL_FreeSurface(sprite_surface);

    const sprite_texture = sdl2.SDL_CreateTextureFromSurface(renderer, sprite_surface) orelse {
        sdl2.SDL_Log("Unable to create sprite texture: %s", sdl2.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    var sheets = try sprite.parseAtlasFile(atlas_text, strings, allocator);
    var sprites = Sprites.init(sprite_texture, sheets);
    return sprites;
}

// Color palette structure and load from palette.txt file
//    pub fn fromFile(file_name: []u8) !Config {
//        var file = try std.fs.cwd().openFile(file_name, .{});
//        defer file.close();
//
//        var buf_reader = std.io.bufferedReader(file.reader());
//        var in_stream = buf_reader.reader();
//
//        var buf: [1024]u8 = undefined;
//        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
//            var parts = std.mem.split(u8, line, ": ");
//
//            const field_name = parts.next();
//            const field_value = parts.next();
//
//            const field_type_info = @typeInfo(field.field_type);
//            if (field.field_type == Color) {} else if (field_type_info == .Int) {
//                var colors = std.mem.split(u8, field_value, " ");
//                @field(config, field.name).r = try std.fmt.parseInt(u8, field_value, 10);
//                @field(config, field.name).g = try std.fmt.parseInt(u8, field_value, 10);
//                @field(config, field.name).b = try std.fmt.parseInt(u8, field_value, 10);
//                @field(config, field.name).a = try std.fmt.parseInt(u8, field_value, 10);
//    color_dark_brown: Color,
//    color_medium_brown: Color,
//    color_light_green: Color,
//    color_tile_blue_light: Color,
//    color_tile_blue_dark: Color,
//    color_light_brown: Color,
//    color_ice_blue: Color,
//    color_dark_blue: Color,
//    color_very_dark_blue: Color,
//    color_orange: Color,
//    color_red: Color,
//    color_light_red: Color,
//    color_medium_grey: Color,
//    color_mint_green: Color,
//    color_blueish_grey: Color,
//    color_pink: Color,
//    color_rose_red: Color,
//    color_light_orange: Color,
//    color_bone_white: Color,
//    color_warm_grey: Color,
//    color_soft_green: Color,
//    color_light_grey: Color,
//    color_shadow: Color,
