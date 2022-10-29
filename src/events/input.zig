const std = @import("std");
const Allocator = std.mem.Allocator;

const math = @import("math");
const Direction = math.direction.Direction;
const Offset = math.direction.Offset;
const Pos = math.pos.Pos;

const core = @import("core");
const ItemClass = core.items.ItemClass;
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const Config = core.config.Config;

const game = @import("game");
const Settings = game.Settings;

const gen = @import("gen");
const MapGenType = gen.MapGenType;

const actions = @import("actions.zig");
const ActionMode = actions.ActionMode;
const InputAction = actions.InputAction;

const TALENT_KEYS: [_]u8 = []u8{ 'q', 'w', 'e', 'r' };
const SKILL_KEYS: [_]u8 = []u8{ 'a', 's', 'd', 'f' };
const ITEM_KEYS: [_]u8 = []u8{ 'z', 'x', 'c' };
const CLASSES: [_]ItemClass = []ItemClass{ ItemClass.primary, ItemClass.consumable, ItemClass.misc };
const DEBUG_TOGGLE_KEY: u8 = '\\';

pub const KeyDir = enum {
    up,
    held,
    down,
};

pub const InputDirection = union(enum) {
    dir: Direction,
    current: void,

    pub fn fromChar(chr: u8) ?Offset {
        if (directionFromDigit(chr)) |dir| {
            return InputDirection{ .dir = dir };
        } else if (chr == '5') {
            return InputDirection.current;
        } else {
            return null;
        }
    }
};

fn directionFromDigit(chr: u8) ?Direction {
    return switch (chr) {
        '4' => Direction.left,
        '6' => Direction.right,
        '8' => Direction.up,
        '2' => Direction.down,
        '1' => Direction.downLeft,
        '3' => Direction.downRight,
        '7' => Direction.upLeft,
        '9' => Direction.upRight,
        else => null,
    };
}

pub const Target = union(enum) {
    item: ItemClass,
    skill: usize,
    talent: usize,
};

pub const MouseClick = enum {
    left,
    right,
    middle,
};

pub const HeldState = struct {
    down_time: u32,
    repetitions: usize,

    pub fn init(down_time: u32, repetitions: usize) HeldState {
        return HeldState{ .down_time = down_time, .repetitions = repetitions };
    }

    pub fn repeated(self: HeldState) HeldState {
        return HeldState.init(self.down_time, self.repetitions + 1);
    }
};

pub const MouseState = struct {
    x: i32 = 0,
    y: i32 = 0,
    left_pressed: bool = false,
    middle_pressed: bool = false,
    right_pressed: bool = false,
    wheel: f32 = 0.0,
};

pub const InputEvent = union(enum) {
    char: struct { chr: u8, keyDir: KeyDir },
    ctrl: KeyDir,
    shift: KeyDir,
    alt: KeyDir,
    enter: KeyDir,
    mousePos: struct { x: i32, y: i32 },
    mouseButton: struct { click: MouseClick, pos: Pos, keyDir: KeyDir },
    esc,
    tab,
    quit,
};

pub const Input = struct {
    ctrl: bool,
    alt: bool,
    shift: bool,
    target: ?Target,
    direction: ?InputDirection,
    char_down_order: std.ArrayList(u8),
    char_held: std.AutoHashMap(u8, HeldState),
    //mouse: MouseState,

    pub fn init(allocator: Allocator) Input {
        return Input{
            .ctrl = false,
            .alt = false,
            .shift = false,
            .target = null,
            .direction = null,
            .char_down_order = std.ArrayList(u8).init(allocator),
            .char_held = std.AutoHashMap(u8, HeldState).init(allocator),
            //.mouse = MouseState.init(),
        };
    }

    pub fn action_mode(self: Input) ActionMode {
        if (self.ctrl) {
            return ActionMode.alternate;
        } else {
            return ActionMode.primary;
        }
    }

    pub fn is_held(self: Input, chr: u8) bool {
        if (self.char_held.get(chr)) |held_state| {
            return held_state.repetitions > 0;
        }

        return false;
    }

    pub fn handleEvent(self: *Input, event: InputEvent, settings: *Settings, ticks: u64, config: *const Config) InputAction {
        var action = InputAction.none;

        // Remember characters that are pressed down.
        if (event == InputEvent.char) {
            if (event.char.dir == KeyDir.down) {
                const held_state = HeldState.init(ticks, 0);
                self.char_held.insert(event.char.chr, held_state);
            }
        }

        switch (event) {
            InputEvent.mousePos => {
                // we don't use the mouse position within the game
            },

            InputEvent.quit => {
                action = InputAction.forceExit;
            },

            InputEvent.esc => {
                action = InputAction.esc;
            },

            InputEvent.tab => {
                action = InputAction.cursorReturn;
            },

            InputEvent.enter => |dir| {
                if (dir == KeyDir.up) {
                    action = InputAction.moveTowardsCursor;
                }
            },

            InputEvent.ctrl => |dir| {
                if (dir != KeyDir.held) {
                    self.ctrl = dir == KeyDir.down;
                }

                switch (dir) {
                    KeyDir.down => action = InputAction.sneak,
                    KeyDir.up => action = InputAction.walk,
                    _ => {},
                }
            },

            InputEvent.shift => |dir| {
                if (dir != KeyDir.held) {
                    self.shift = dir == KeyDir.down;
                }

                switch (dir) {
                    KeyDir.down => action = InputAction.run,
                    KeyDir.up => action = InputAction.walk,
                    _ => {},
                }
            },

            InputEvent.alt => |dir| {
                if (dir != KeyDir.held) {
                    self.alt = dir == KeyDir.down;
                }

                if (dir == KeyDir.down) {
                    action = InputAction.alt;
                }
            },

            InputEvent.char => |chr| {
                action = self.handle_char(chr.chr, chr.dir, ticks, settings, config);
            },

            InputEvent.mouseButton => |button| {
                action = self.handle_mouse_button(button.clicked, button.mouse_pos, button.dir);
            },
        }

        return action;
    }

    fn handleChar(self: *Input, chr: u8, dir: KeyDir, ticks: u32, settings: *const Settings, config: *const Config) InputAction {
        return switch (dir) {
            KeyDir.up => self.handleCharUp(chr, settings),
            KeyDir.down => self.handleCharDown(chr, settings),
            KeyDir.held => self.handleCharHeld(chr, ticks, settings, config),
        };
    }

    fn handleCharUp(self: *Input, chr: u8, settings: *const Settings) InputAction {
        if (std.mem.indexOfScalar(u8, chr, self.char_down_order.items)) |index| {
            self.char_down_order.remove(index);
        }

        const is_held = self.isHeld(chr);
        self.char_held.remove(chr);

        if (settings.state.isMenu()) {
            if (chr.isAsciiDigit()) {
                return InputAction.selectEntry(@intCast(usize, chr.toDigit(10)));
            } else {
                return menuAlphaUpToAction(chr, self.shift);
            }
        } else if (settings.state == GameState.use) {
            if (InputDirection.fromChr(chr)) |input_dir| {
                if (input_dir == InputDirection.dir) {
                    if (self.direction != null) {
                        return InputAction.finalizeUse;
                    }
                } else {
                    return InputAction.dropItem;
                }
            } else if (getTalentIndex(chr) != null) {
                // Releasing the talent does not take you out of use-mode.
            } else if (getItemIndex(chr) != null) {
                // Releasing the item does not take you out of use-mode.
            } else if (getSkillIndex(chr) != null) {
                // Releasing a skill key does not take you out of use-mode.
            } else {
                return self.apply_char(chr, settings);
            }

            return InputAction.none;
        } else {
            // if key was held, do nothing when it is up to avoid a final press
            if (is_held) {
                self.clear_char_state(chr);
                return InputAction.none;
            } else {
                const action: InputAction = self.apply_char(chr, settings);

                self.clear_char_state(chr);

                return action;
            }
        }
    }

    fn handleCharDownUseMode(self: *Input, chr: u8, _settings: *const Settings) InputAction {
        var action = InputAction.none;

        if (InputDirection.fromChr(chr)) |input_dir| {
            if (input_dir == InputDirection.dir) {
                // directions are now applied immediately
                action = InputAction.useDir(input_dir.useDir.dir);
                self.direction = input_dir.useDir.dir;
            }
        } else if (chr == ' ') {
            action = InputAction.abortUse;
        } else if (getItemIndex(key)) |index| {
            const item_class = CLASSES[index];

            // check if you press down the same item again, aborting use-mode
            if (self.target == Target.Item) {
                action = InputAction.abortUse;
                self.target = none;
            } else {
                self.target = Some(Target.item(item_class));
                action = InputAction.startUseItem(item_class);
            }
        } else if (getSkillIndex(chr)) |index| {
            // check if you press down the same item again, aborting use-mode
            if (self.target == Target.skill(index)) {
                action = InputAction.abortUse;
                self.target = null;
            } else {
                self.target = Target.skill(index);
                action = InputAction.startUseSkill(index, self.actionMode());
            }
        }

        return action;
    }

    fn handleCharDown(self: *Input, chr: u8, settings: *const Settings) InputAction {
        // intercept debug toggle so it is not part of the regular control flow.
        if (chr == DEBUG_TOGGLE_KEY) {
            return InputAction.debugToggle;
        }

        const action = InputAction.none;

        self.char_down_order.push(chr);

        if (settings.state == GameState.use) {
            action = self.handle_char_down_use_mode(chr, settings);
        } else if (!settings.state.isMenu()) {
            if (chr == 'o') {
                action = InputAction.overlayToggle;
            } else if (chr == ' ') {
                action = InputAction.cursorToggle;
            } else if (InputDirection.fromChr(chr)) |input_dir| {
                self.direction = input_dir;
            } else if (!(settings.isCursorMode() and self.ctrl)) {
                if (getItemIndex(chr)) |index| {
                    const item_class = CLASSES[index];
                    self.target = Some(Target.item(item_class));

                    action = InputAction.startUseItem(item_class);
                    // directions are cleared when entering use-mode
                    self.direction = None;
                } else if (getSkillIndex(chr)) |index| {
                    self.target = Target.skill(index);

                    action = InputAction.startUseSkill(index, self.action_mode());
                    // directions are cleared when entering use-mode
                    self.direction = None;
                } else if (getTalentIndex(chr)) |index| {
                    self.target = Target.talent(index);

                    action = InputAction.startUseTalent(index);
                    // directions are cleared when entering use-mode
                    self.direction = None;
                }
            }
        }

        return action;
    }

    fn handleCharHeld(self: *Input, chr: u8, ticks: u32, settings: *const Settings, config: *const Config) InputAction {
        var action = InputAction.none;

        if (self.char_held.get(chr)) |held_state| {
            // only process the last character as held
            if (self.char_down_order.iter().last()) |chr| {
                const held_state = *held_state;
                //const time_since = held_state.down_time - ticks;
                const time_since = ticks - held_state.down_time;

                const new_repeats = @floatToInt(usize, @intToFloat(f32, time_since) / config.repeat_delay);
                if (new_repeats > held_state.repetitions) {
                    action = self.apply_char(chr, settings);

                    if (action == InputAction.overlayToggle or
                        action == InputAction.inventory or
                        action == InputAction.skillMenu or
                        action == InputAction.exit or
                        action == InputAction.cursorToggle or
                        action == InputAction.classMenu)
                    {
                        action = InputAction.none;
                    } else {
                        self.char_held.insert(chr, held_state.repeated());
                    }
                }
            }
        }

        return action;
    }

    fn handleMouseButton(self: *Input, clicked: MouseClick, _mouse_pos: Pos, dir: KeyDir) InputAction {
        return InputAction.mouseButton(clicked, dir);
    }

    /// Clear direction or target state for the given character, if applicable.
    fn clearCharState(self: *Input, chr: u8) void {
        if (InputDirection.fromChr(chr) != null) {
            self.direction = .none;
        }

        if (getTalentIndex(chr) != null) {
            self.target = .none;
        }

        if (getSkillIndex(chr) != null) {
            self.target = .none;
        }

        if (getItemIndex(chr) != null) {
            self.target = .none;
        }
    }

    fn applyChar(self: *Input, chr: u8, settings: *const Settings) InputAction {
        var action: InputAction = InputAction.none;

        // check if the key being released is the one that set the input direction.
        if (InputDirection.fromChr(chr)) |input_dir| {
            if (self.direction == input_dir) {
                switch (input_dir) {
                    InputDirection.dir(dir) => {
                        if (settings.isCursorMode()) {
                            action = InputAction.cursorMove(dir, self.ctrl, self.shift);
                        } else {
                            action = InputAction.move(dir);
                        }
                    },

                    InputDirection.current => {
                        if (settings.isCursorMode() and self.ctrl) {
                            action = InputAction.cursorReturn;
                        } else {
                            action = InputAction.pass;
                        }
                    },
                }
            }
            // if releasing a key that is directional, but not the last directional key
            // pressed, then do nothing, waiting for the last key to be released instead.
        } else {
            if (settings.isCursorMode()) {
                if (getItemIndex(chr)) |index| {
                    const item_class = CLASSES[index];
                    const cursor_pos = settings.cursor.unwrap();
                    action = InputAction.throwItem(cursor_pos, item_class);
                }
            }

            // If we are not releasing a direction, skill, or item then try other keys.
            if (action == InputAction.none) {
                action = alphaUpToAction(chr, self.shift);
            }
        }

        return action;
    }
};

pub fn menuAlphaUpToAction(chr: u8, shift: bool) InputAction {
    return switch (chr) {
        'r' => InputAction.restart,
        'q' => InputAction.exit,
        'i' => InputAction.inventory,
        'l' => InputAction.exploreAll,
        't' => InputAction.testMode,
        'p' => InputAction.regenerateMap,
        'j' => kkillMenu,
        'h' => classMenu,
        '/' => {
            // shift + / = ?
            if (shift) {
                InputAction.helpMenu;
            } else {
                InputAction.none;
            }
        },

        else => InputAction.none,
    };
}

pub fn alpha_up_to_action(chr: u8, shift: bool) InputAction {
    return switch (chr) {
        'r' => InputAction.restart,
        'g' => InputAction.pickup,
        'i' => InputAction.inventory,
        'y' => InputAction.yell,
        'l' => InputAction.exploreAll,
        't' => InputAction.testMode,
        'p' => InputAction.regenerateMap,
        'j' => InputAction.skillMenu,
        'h' => InputAction.classMenu,
        '/' =>
        // shift + / = ?
        if (shift) {
            return InputAction.helpMenu;
        } else {
            return InputAction.none;
        },

        else => InputAction.none,
    };
}

fn directionFromDigit(chr: char) ?Direction {
    return switch (chr) {
        '4' => Direction.left,
        '6' => Direction.right,
        '8' => Direction.up,
        '2' => Direction.down,
        '1' => Direction.downLeft,
        '3' => Direction.downRight,
        '7' => Direction.upLeft,
        '9' => Direction.upRight,
        _ => null,
    };
}

fn getTalentIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, TALENT_KEYS, chr);
}

fn getItemIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, ITEM_KEYS, chr);
}

fn getSkillIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, SKILL_KEYS, chr);
}
