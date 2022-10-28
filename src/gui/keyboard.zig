const sdl2 = @import("sdl2.zig");

const math = @import("math");
const Pos = math.pos.Pos;

const events = @import("events");
const InputEvent = events.InputEvent;
const KeyDir = events.KeyDir;
const MouseButton = events.MouseButton;
const MouseClick = events.MouseClick;

//// var event: c.SDL_Event = undefined;
////while (c.SDL_PollEvent(&event) != 0) {
//    switch (event.@"type") {
//        c.SDL_QUIT => {
//            quit = true;
//        },
//
//        // SDL_Scancode scancode;      /**< SDL physical key code - see ::SDL_Scancode for details */
//        // SDL_Keycode sym;            /**< SDL virtual key code - see ::SDL_Keycode for details */
//        // Uint16 mod;                 /**< current key modifiers */
//        c.SDL_KEYDOWN => {
//            const code: i32 = event.key.keysym.sym;
//            const key: c.SDL_KeyCode = @intToEnum(c.SDL_KeyCode, code);
//
//            const a_code = @enumToInt(c.SDL_KeyCode.SDLK_a);
//            const z_code = @enumToInt(c.SDL_KeyCode.SDLK_z);
//
//            if (key == c.SDL_KeyCode.SDLK_RETURN) {
//                c.SDL_Log("Pressed enter");
//            } else if (key == c.SDL_KeyCode.SDLK_ESCAPE) {
//                quit = true;
//            } else if (key == c.SDL_KeyCode.SDLK_SPACE) {
//                self.state.append(@intCast(u8, code));
//            } else if (key == c.SDL_KeyCode.SDLK_BACKSPACE) {
//                self.state.backspace();
//            } else if (code >= a_code and code <= z_code) {
//                self.state.append(@intCast(u8, code));
//            } else {
//                c.SDL_Log("Pressed: %c", key);
//            }
//        },
//
//        c.SDL_KEYUP => {},
//
//        c.SDL_MOUSEMOTION => {
//            self.state.mouse = c.SDL_Point{ .x = event.motion.x, .y = event.motion.y };
//        },
//
//        c.SDL_MOUSEBUTTONDOWN => {},
//
//        c.SDL_MOUSEBUTTONUP => {},
//
//        c.SDL_MOUSEWHEEL => {},
//
//        // just for fun...
//        c.SDL_DROPFILE => {
//            c.SDL_Log("Dropped file '%s'", event.drop.file);
//        },
//        c.SDL_DROPTEXT => {
//            c.SDL_Log("Dropped text '%s'", event.drop.file);
//        },
//        c.SDL_DROPBEGIN => {
//            c.SDL_Log("Drop start");
//        },
//        c.SDL_DROPCOMPLETE => {
//            c.SDL_Log("Drop done");
//        },
//
//        // could be used for clock tick
//        c.SDL_USEREVENT => {},
//
//        else => {},
//    }
//}

pub fn translateEvent(event: sdl2.SDL_Event) ?InputEvent {
    switch (event.@"type") {
        sdl2.SDL_QUIT => {
            return InputEvent.Quit;
        },

        sdl2.SDL_KEYDOWN => {
            const keycode: i32 = event.key.keysym.sym;

            var dir = KeyDir.Down;

            if (event.key.repeat) {
                dir = KeyDir.Held;
            }

            if (keycodeToChar(keycode)) |chr| {
                return InputEvent.Char(chr, dir);
            } else if (keycode == sdl2.SDLK_LCTRL or keycode == sdl2.SDLK_RCTRL) {
                return InputEvent.Ctrl(dir);
            } else if (keycode == sdl2.SDLK_LALT or keycode == sdl2.SDLK_RALT) {
                return InputEvent.Alt(dir);
            } else if (keycode == sdl2.SDLK_LSHIFT or keycode == sdl2.SDLK_RSHIFT) {
                return InputEvent.Shift(dir);
            } else if (keycode == sdl2.SDLK_KP_ENTER or keycode == sdl2.SDLK_RETURN) {
                // TODO what about RETURN2
                return InputEvent.Enter(KeyDir.Down);
            } else {
                return null;
            }

            return null;
        },

        sdl2.SDL_KEYUP => {
            const keycode: i32 = event.key.keysym.sym;

            if (event.key.repeat) {
                return null;
            }

            if (keycodeToChar(keycode)) |chr| {
                return InputEvent.Char(chr, KeyDir.Up);
            } else if (keycode == sdl2.SDLK_LCTRL or keycode == sdl2.SDLK_RCTRL) {
                return InputEvent.Ctrl(KeyDir.Up);
            } else if (keycode == sdl2.SDLK_LALT or keycode == sdl2.SDLK_RALT) {
                return InputEvent.Alt(KeyDir.Up);
            } else if (keycode == sdl2.SDLK_KP_TAB) {
                return InputEvent.Tab;
            } else if (keycode == sdl2.SDLK_ESCAPE) {
                return InputEvent.Esc;
            } else if (keycode == sdl2.SDLK_LSHIFT or keycode == sdl2.SDLK_RSHIFT) {
                return InputEvent.Shift(KeyDir.Up);
            } else if (keycode == sdl2.SDLK_KP_ENTER or keycode == sdl2.SDLK_RETURN) {
                return InputEvent.Enter(KeyDir.Up);
            } else {
                // NOTE could check for LShift, RShift
                return null;
            }

            return null;
        },

        sdl2.SDL_MOUSEMOTION => {
            return InputEvent.MousePos(event.motion.x, event.motion.y);
        },

        sdl2.SDL_MOUSEBUTTONDOWN => {
            var click = undefined;
            switch (event.button.mouse_btn) {
                MouseButton.Left => {
                    click = MouseClick.Left;
                },

                MouseButton.Right => {
                    click = MouseClick.Right;
                },

                MouseButton.Middle => {
                    click = MouseClick.Middle;
                },

                _ => return null,
            }

            const mouse_pos = Pos.new(event.button.x, event.button.y);
            return InputEvent.MouseButton(click, mouse_pos, KeyDir.Down);
        },

        sdl2.SDL_MOUSEBUTTONUP => {
            var click = undefined;
            switch (event.button.mouse_btn) {
                MouseButton.Left => {
                    click = MouseClick.Left;
                },

                MouseButton.Right => {
                    click = MouseClick.Right;
                },

                MouseButton.Middle => {
                    click = MouseClick.Middle;
                },

                _ => return null,
            }

            const mouse_pos = Pos.new(event.button.x, event.button.y);
            return InputEvent.MouseButton(click, mouse_pos, KeyDir.Up);
        },

        else => {
            return null;
        },
    }
}

pub fn keycodeToChar(key: u8) ?u8 {
    switch (key) {
        sdl2.SDLK_SPACE => ' ',
        sdl2.SDLK_COMMA => ',',
        sdl2.SDLK_MINUS => '-',
        sdl2.SDLK_PERIOD => '.',
        sdl2.SDLK_NUM0 => '0',
        sdl2.SDLK_NUM1 => '1',
        sdl2.SDLK_NUM2 => '2',
        sdl2.SDLK_NUM3 => '3',
        sdl2.SDLK_NUM4 => '4',
        sdl2.SDLK_NUM5 => '5',
        sdl2.SDLK_NUM6 => '6',
        sdl2.SDLK_NUM7 => '7',
        sdl2.SDLK_NUM8 => '8',
        sdl2.SDLK_NUM9 => '9',
        sdl2.SDLK_A => 'a',
        sdl2.SDLK_B => 'b',
        sdl2.SDLK_C => 'c',
        sdl2.SDLK_D => 'd',
        sdl2.SDLK_E => 'e',
        sdl2.SDLK_F => 'f',
        sdl2.SDLK_G => 'g',
        sdl2.SDLK_H => 'h',
        sdl2.SDLK_I => 'i',
        sdl2.SDLK_J => 'j',
        sdl2.SDLK_K => 'k',
        sdl2.SDLK_L => 'l',
        sdl2.SDLK_M => 'm',
        sdl2.SDLK_N => 'n',
        sdl2.SDLK_O => 'o',
        sdl2.SDLK_P => 'p',
        sdl2.SDLK_Q => 'q',
        sdl2.SDLK_R => 'r',
        sdl2.SDLK_S => 's',
        sdl2.SDLK_T => 't',
        sdl2.SDLK_U => 'u',
        sdl2.SDLK_V => 'v',
        sdl2.SDLK_W => 'w',
        sdl2.SDLK_X => 'x',
        sdl2.SDLK_Y => 'y',
        sdl2.SDLK_Z => 'z',
        sdl2.SDLK_RIGHT => '6',
        sdl2.SDLK_LEFT => '4',
        sdl2.SDLK_DOWN => '2',
        sdl2.SDLK_UP => '8',
        sdl2.SDLK_KP0 => '0',
        sdl2.SDLK_KP1 => '1',
        sdl2.SDLK_KP2 => '2',
        sdl2.SDLK_KP3 => '3',
        sdl2.SDLK_KP4 => '4',
        sdl2.SDLK_KP5 => '5',
        sdl2.SDLK_KP6 => '6',
        sdl2.SDLK_KP7 => '7',
        sdl2.SDLK_KP8 => '8',
        sdl2.SDLK_KP9 => '9',
        sdl2.SDLK_KPPERIOD => '.',
        sdl2.SDLK_KPSPACE => ' ',
        sdl2.SDLK_LEFTBRACKET => '[',
        sdl2.SDLK_RIGHTBRACKET => ']',
        sdl2.SDLK_BACKQUOTE => '`',
        sdl2.SDLK_BACKSLASH => '\\',
        sdl2.SDLK_QUESTION => '?',
        sdl2.SDLK_SLASH => '/',
        else => null,
    }
}
