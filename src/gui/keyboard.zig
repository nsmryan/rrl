const sdl2 = @import("sdl2.zig");

const math = @import("math");
const Pos = math.pos.Pos;

const engine = @import("engine");
const InputEvent = engine.input.InputEvent;
const KeyDir = engine.input.KeyDir;
const MouseClick = engine.input.MouseClick;

pub fn translateEvent(event: sdl2.SDL_Event) ?InputEvent {
    switch (event.@"type") {
        sdl2.SDL_QUIT => {
            return InputEvent.quit;
        },

        sdl2.SDL_KEYDOWN => {
            const keycode: i32 = event.key.keysym.sym;

            var dir = KeyDir.down;

            if (event.key.repeat == 1) {
                dir = KeyDir.held;
            }

            if (keycodeToChar(keycode)) |chr| {
                return InputEvent{ .char = .{ .chr = chr, .keyDir = dir } };
            } else if (keycode == sdl2.SDLK_LCTRL or keycode == sdl2.SDLK_RCTRL) {
                return InputEvent{ .ctrl = dir };
            } else if (keycode == sdl2.SDLK_LALT or keycode == sdl2.SDLK_RALT) {
                return InputEvent{ .alt = dir };
            } else if (keycode == sdl2.SDLK_LSHIFT or keycode == sdl2.SDLK_RSHIFT) {
                return InputEvent{ .shift = dir };
            } else if (keycode == sdl2.SDLK_KP_ENTER or keycode == sdl2.SDLK_RETURN) {
                // TODO what about RETURN2
                return InputEvent{ .enter = KeyDir.down };
            } else {
                return null;
            }

            return null;
        },

        sdl2.SDL_KEYUP => {
            const keycode: i32 = event.key.keysym.sym;

            if (event.key.repeat == 1) {
                return null;
            }

            if (keycodeToChar(keycode)) |chr| {
                return InputEvent{ .char = .{ .chr = chr, .keyDir = KeyDir.up } };
            } else if (keycode == sdl2.SDLK_LCTRL or keycode == sdl2.SDLK_RCTRL) {
                return InputEvent{ .ctrl = KeyDir.up };
            } else if (keycode == sdl2.SDLK_LALT or keycode == sdl2.SDLK_RALT) {
                return InputEvent{ .alt = KeyDir.up };
            } else if (keycode == sdl2.SDLK_KP_TAB) {
                return InputEvent.tab;
            } else if (keycode == sdl2.SDLK_ESCAPE) {
                return InputEvent.esc;
            } else if (keycode == sdl2.SDLK_LSHIFT or keycode == sdl2.SDLK_RSHIFT) {
                return InputEvent{ .shift = KeyDir.up };
            } else if (keycode == sdl2.SDLK_KP_ENTER or keycode == sdl2.SDLK_RETURN) {
                return InputEvent{ .enter = KeyDir.up };
            } else {
                // NOTE could check for LShift, RShift
                return null;
            }

            return null;
        },

        sdl2.SDL_MOUSEBUTTONDOWN => {
            var click: MouseClick = undefined;
            switch (event.button.button) {
                sdl2.SDL_BUTTON_LEFT => {
                    click = MouseClick.left;
                },

                sdl2.SDL_BUTTON_RIGHT => {
                    click = MouseClick.right;
                },

                sdl2.SDL_BUTTON_MIDDLE => {
                    click = MouseClick.middle;
                },

                else => return null,
            }

            const mouse_pos = Pos.init(event.button.x, event.button.y);
            return InputEvent{ .mouseClick = .{ .click = click, .pos = mouse_pos, .keyDir = KeyDir.down } };
        },

        sdl2.SDL_MOUSEBUTTONUP => {
            var click: MouseClick = undefined;
            switch (event.button.button) {
                sdl2.SDL_BUTTON_LEFT => {
                    click = MouseClick.left;
                },

                sdl2.SDL_BUTTON_RIGHT => {
                    click = MouseClick.right;
                },

                sdl2.SDL_BUTTON_MIDDLE => {
                    click = MouseClick.middle;
                },

                else => return null,
            }

            const mouse_pos = Pos.init(event.button.x, event.button.y);
            return InputEvent{ .mouseClick = .{ .click = click, .pos = mouse_pos, .keyDir = KeyDir.up } };
        },

        else => {
            return null;
        },
    }
}

pub fn keycodeToChar(key: i32) ?u8 {
    return switch (key) {
        sdl2.SDLK_SPACE => ' ',
        sdl2.SDLK_COMMA => ',',
        sdl2.SDLK_MINUS => '-',
        sdl2.SDLK_PERIOD => '.',
        sdl2.SDLK_0 => '0',
        sdl2.SDLK_1 => '1',
        sdl2.SDLK_2 => '2',
        sdl2.SDLK_3 => '3',
        sdl2.SDLK_4 => '4',
        sdl2.SDLK_5 => '5',
        sdl2.SDLK_6 => '6',
        sdl2.SDLK_7 => '7',
        sdl2.SDLK_8 => '8',
        sdl2.SDLK_9 => '9',
        sdl2.SDLK_a => 'a',
        sdl2.SDLK_b => 'b',
        sdl2.SDLK_c => 'c',
        sdl2.SDLK_d => 'd',
        sdl2.SDLK_e => 'e',
        sdl2.SDLK_f => 'f',
        sdl2.SDLK_g => 'g',
        sdl2.SDLK_h => 'h',
        sdl2.SDLK_i => 'i',
        sdl2.SDLK_j => 'j',
        sdl2.SDLK_k => 'k',
        sdl2.SDLK_l => 'l',
        sdl2.SDLK_m => 'm',
        sdl2.SDLK_n => 'n',
        sdl2.SDLK_o => 'o',
        sdl2.SDLK_p => 'p',
        sdl2.SDLK_q => 'q',
        sdl2.SDLK_r => 'r',
        sdl2.SDLK_s => 's',
        sdl2.SDLK_t => 't',
        sdl2.SDLK_u => 'u',
        sdl2.SDLK_v => 'v',
        sdl2.SDLK_w => 'w',
        sdl2.SDLK_x => 'x',
        sdl2.SDLK_y => 'y',
        sdl2.SDLK_z => 'z',
        sdl2.SDLK_RIGHT => '6',
        sdl2.SDLK_LEFT => '4',
        sdl2.SDLK_DOWN => '2',
        sdl2.SDLK_UP => '8',
        sdl2.SDLK_KP_0 => '0',
        sdl2.SDLK_KP_1 => '1',
        sdl2.SDLK_KP_2 => '2',
        sdl2.SDLK_KP_3 => '3',
        sdl2.SDLK_KP_4 => '4',
        sdl2.SDLK_KP_5 => '5',
        sdl2.SDLK_KP_6 => '6',
        sdl2.SDLK_KP_7 => '7',
        sdl2.SDLK_KP_8 => '8',
        sdl2.SDLK_KP_9 => '9',
        sdl2.SDLK_KP_PERIOD => '.',
        sdl2.SDLK_KP_SPACE => ' ',
        sdl2.SDLK_LEFTBRACKET => '[',
        sdl2.SDLK_RIGHTBRACKET => ']',
        sdl2.SDLK_BACKQUOTE => '`',
        sdl2.SDLK_BACKSLASH => '\\',
        sdl2.SDLK_QUESTION => '?',
        sdl2.SDLK_SLASH => '/',
        else => null,
    };
}
