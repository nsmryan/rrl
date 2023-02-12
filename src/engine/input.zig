const std = @import("std");
const Allocator = std.mem.Allocator;

const math = @import("math");
const Direction = math.direction.Direction;
const Offset = math.direction.Offset;
const Pos = math.pos.Pos;

const core = @import("core");
const InventorySlot = core.items.InventorySlot;
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const Config = core.config.Config;

const gen = @import("gen");
const MapGenType = gen.MapGenType;

const actions = @import("actions.zig");
const ActionMode = actions.ActionMode;
const InputAction = actions.InputAction;
const s = @import("settings.zig");
const GameState = s.GameState;
const Settings = s.Settings;

const TALENT_KEYS = [_]u8{ 'q', 'w', 'e', 'r' };
const SKILL_KEYS = [_]u8{ 'a', 's', 'd', 'f' };
const ITEM_KEYS = [_]u8{ 'z', 'x', 'c', 'v' };
const SLOTS = [_]InventorySlot{ .weapon, .throwing, .artifact0, .artifact1 };
const DEBUG_TOGGLE_KEY: u8 = '\\';

const REPEAT_DELAY: f32 = 0.35;

pub const KeyDir = enum {
    up,
    held,
    down,
};

pub const InputDirection = union(enum) {
    dir: Direction,
    current: void,

    pub fn fromChar(chr: u8) ?InputDirection {
        if (directionFromDigit(chr)) |dir| {
            return InputDirection{ .dir = dir };
        } else if (chr == '5') {
            return InputDirection.current;
        } else {
            return null;
        }
    }
};

pub const Target = union(enum) {
    slot: InventorySlot,
    skill: usize,
    talent: usize,
};

pub const MouseClick = enum {
    left,
    right,
    middle,
};

pub const HeldState = struct {
    down_time: u64,
    repetitions: usize,

    pub fn init(down_time: u64, repetitions: usize) HeldState {
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
    mouseClick: struct { click: MouseClick, pos: Pos, keyDir: KeyDir },
    esc,
    tab,
    quit,

    pub fn initChar(chr: u8, keyDir: KeyDir) InputEvent {
        return InputEvent{ .char = .{ .chr = chr, .keyDir = keyDir } };
    }
};

pub const Input = struct {
    ctrl: bool,
    alt: bool,
    shift: bool,
    target: ?Target,
    direction: ?InputDirection,
    char_down_order: std.ArrayList(u8),
    char_held: std.AutoArrayHashMap(u8, HeldState),
    //mouse: MouseState,

    pub fn init(allocator: Allocator) Input {
        return Input{
            .ctrl = false,
            .alt = false,
            .shift = false,
            .target = null,
            .direction = null,
            .char_down_order = std.ArrayList(u8).init(allocator),
            .char_held = std.AutoArrayHashMap(u8, HeldState).init(allocator),
            //.mouse = MouseState.init(),
        };
    }

    pub fn deinit(input: *Input) void {
        input.char_down_order.deinit();
        input.char_held.deinit();
    }

    pub fn actionMode(self: Input) ActionMode {
        if (self.ctrl) {
            return ActionMode.alternate;
        } else {
            return ActionMode.primary;
        }
    }

    pub fn isHeld(self: Input, chr: u8) bool {
        if (self.char_held.get(chr)) |held_state| {
            return held_state.repetitions > 0;
        }

        return false;
    }

    pub fn handleEvent(self: *Input, event: InputEvent, settings: *Settings, ticks: u64) !InputAction {
        var action: InputAction = InputAction.none;

        // Remember characters that are pressed down.
        if (event == InputEvent.char) {
            if (event.char.keyDir == KeyDir.down) {
                const held_state = HeldState.init(ticks, 0);
                try self.char_held.put(event.char.chr, held_state);
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
                    else => {},
                }
            },

            InputEvent.shift => |dir| {
                if (dir != KeyDir.held) {
                    self.shift = dir == KeyDir.down;
                }

                switch (dir) {
                    KeyDir.down => action = InputAction.run,
                    KeyDir.up => action = InputAction.walk,
                    else => {},
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
                action = try self.handleChar(chr.chr, chr.keyDir, ticks, settings);
            },

            InputEvent.mouseClick => |click| {
                _ = click;
            },
        }

        return action;
    }

    fn handleChar(self: *Input, chr: u8, dir: KeyDir, ticks: u64, settings: *const Settings) !InputAction {
        return switch (dir) {
            KeyDir.up => try self.handleCharUp(chr, settings),
            KeyDir.down => self.handleCharDown(chr, settings),
            KeyDir.held => try self.handleCharHeld(chr, ticks, settings),
        };
    }

    fn handleCharUp(self: *Input, chr: u8, settings: *const Settings) !InputAction {
        if (std.mem.indexOfScalar(u8, self.char_down_order.items, chr)) |index| {
            _ = self.char_down_order.orderedRemove(index);
        }

        const is_held = self.isHeld(chr);
        _ = self.char_held.orderedRemove(chr);

        if (settings.state.isMenu()) {
            if (std.ascii.isDigit(chr)) {
                return InputAction{ .selectEntry = @intCast(usize, chr - '0') };
            } else {
                return menuAlphaUpToAction(chr, self.shift);
            }
        } else if (settings.state == GameState.use) {
            if (InputDirection.fromChar(chr)) |input_dir| {
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
                return self.applyChar(chr, settings);
            }

            return InputAction.none;
        } else {
            // if key was held, do nothing when it is up to avoid a final press
            if (is_held) {
                self.clearCharState(chr);
                return InputAction.none;
            } else {
                const action: InputAction = self.applyChar(chr, settings);

                self.clearCharState(chr);

                return action;
            }
        }
    }

    fn handleCharDownUseMode(self: *Input, chr: u8) InputAction {
        var action: InputAction = InputAction.none;

        if (InputDirection.fromChar(chr)) |input_dir| {
            if (input_dir == InputDirection.dir) {
                // directions are now applied immediately
                action = InputAction{ .useDir = input_dir.dir };
                self.direction = input_dir;
            }
        } else if (chr == ' ') {
            action = InputAction.abortUse;
        } else if (getItemIndex(chr)) |index| {
            const slot = SLOTS[index];

            // check if you press down the same item again, aborting use-mode
            if (self.target != null and self.target.? == Target.item) {
                action = InputAction.abortUse;
                self.target = null;
            } else {
                self.target = Target{ .item = slot };
                action = InputAction{ .startUseItem = slot };
            }
        } else if (getSkillIndex(chr)) |index| {
            // check if you press down the same item again, aborting use-mode
            if (std.meta.eql(self.target, Target{ .skill = index })) {
                action = InputAction.abortUse;
                self.target = null;
            } else {
                self.target = Target{ .skill = index };
                action = InputAction{ .startUseSkill = .{ .index = index, .action = self.actionMode() } };
            }
        }

        return action;
    }

    fn handleCharDown(self: *Input, chr: u8, settings: *const Settings) !InputAction {
        // intercept debug toggle so it is not part of the regular control flow.
        if (chr == DEBUG_TOGGLE_KEY) {
            return InputAction.debugToggle;
        }

        var action: InputAction = InputAction.none;

        try self.char_down_order.append(chr);

        if (settings.state == GameState.use) {
            action = self.handleCharDownUseMode(chr);
        } else if (!settings.state.isMenu()) {
            if (chr == 'o') {
                action = InputAction.overlayToggle;
            } else if (chr == ' ') {
                action = InputAction.cursorToggle;
            } else if (InputDirection.fromChar(chr)) |input_dir| {
                self.direction = input_dir;
            } else if (!(settings.mode == .cursor and self.ctrl)) {
                if (getItemIndex(chr)) |index| {
                    const slot = SLOTS[index];

                    self.target = Target{ .slot = slot };
                    action = InputAction{ .startUseItem = slot };

                    // directions are cleared when entering use-mode
                    self.direction = null;
                } else if (getSkillIndex(chr)) |index| {
                    self.target = Target{ .skill = index };

                    action = InputAction{ .startUseSkill = .{ .index = index, .action = self.actionMode() } };
                    // directions are cleared when entering use-mode
                    self.direction = null;
                } else if (getTalentIndex(chr)) |index| {
                    self.target = Target{ .talent = index };

                    action = InputAction{ .startUseTalent = index };
                    // directions are cleared when entering use-mode
                    self.direction = null;
                }
            }
        }

        return action;
    }

    fn handleCharHeld(self: *Input, chr: u8, ticks: u64, settings: *const Settings) !InputAction {
        var action: InputAction = InputAction.none;

        if (self.char_held.get(chr)) |held_state| {
            // only process the last character as held
            if (self.char_down_order.items.len > 0) {
                const key = self.char_down_order.items[self.char_down_order.items.len - 1];
                const time_since = ticks - held_state.down_time;

                const new_repeats = @floatToInt(usize, @intToFloat(f32, time_since) / REPEAT_DELAY);
                if (new_repeats > held_state.repetitions) {
                    action = self.applyChar(key, settings);

                    if (action == InputAction.overlayToggle or
                        action == InputAction.inventory or
                        action == InputAction.skillMenu or
                        action == InputAction.exit or
                        action == InputAction.cursorToggle or
                        action == InputAction.classMenu)
                    {
                        action = InputAction.none;
                    } else {
                        try self.char_held.put(key, held_state.repeated());
                    }
                }
            }
        }

        return action;
    }

    /// Clear direction or target state for the given character, if applicable.
    fn clearCharState(self: *Input, chr: u8) void {
        if (InputDirection.fromChar(chr) != null) {
            self.direction = null;
        }

        if (getTalentIndex(chr) != null) {
            self.target = null;
        }

        if (getSkillIndex(chr) != null) {
            self.target = null;
        }

        if (getItemIndex(chr) != null) {
            self.target = null;
        }
    }

    fn applyChar(self: *Input, chr: u8, settings: *const Settings) InputAction {
        var action: InputAction = InputAction.none;

        // check if the key being released is the one that set the input direction.
        if (InputDirection.fromChar(chr)) |input_dir| {
            if (self.direction != null and std.meta.eql(self.direction.?, input_dir)) {
                switch (input_dir) {
                    InputDirection.dir => |dir| {
                        if (settings.mode == .cursor) {
                            action = InputAction{ .cursorMove = .{ .dir = dir, .is_relative = self.ctrl, .is_long = self.shift } };
                        } else {
                            action = InputAction{ .move = dir };
                        }
                    },

                    InputDirection.current => {
                        if (settings.mode == .cursor and self.ctrl) {
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
            if (settings.mode == .cursor) {
                if (getItemIndex(chr)) |index| {
                    const slot = SLOTS[index];
                    const cursor_pos = settings.mode.cursor.pos;
                    action = InputAction{ .throwItem = .{ .pos = cursor_pos, .slot = slot } };
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
        'j' => InputAction.skillMenu,
        'h' => InputAction.classMenu,
        '/' => {
            // shift + / = ?
            if (shift) {
                return InputAction.helpMenu;
            } else {
                return InputAction.none;
            }
        },

        else => InputAction.none,
    };
}

pub fn alphaUpToAction(chr: u8, shift: bool) InputAction {
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

fn getTalentIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, &TALENT_KEYS, chr);
}

fn getItemIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, &ITEM_KEYS, chr);
}

fn getSkillIndex(chr: u8) ?usize {
    return std.mem.indexOfScalar(u8, &SKILL_KEYS, chr);
}

test "test input movement" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var input = Input.init(allocator);
    defer input.deinit();
    var settings = Settings.init();
    const time = 0;

    {
        const event = InputEvent.initChar('4', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.none, input_action);
    }

    {
        const event = InputEvent.initChar('4', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .move = Direction.left }, input_action);
    }
}

test "test input use mode enter" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var input = Input.init(allocator);
    defer input.deinit();
    var settings = Settings.init();
    const time = 0;

    {
        const event = InputEvent.initChar('z', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .startUseItem = InventorySlot.weapon }, input_action);
    }

    // letting item up outside of use-mode does not cause any action.
    {
        const event = InputEvent.initChar('z', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.none, input_action);
    }

    // down and up
    {
        const event = InputEvent.initChar('z', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .startUseItem = InventorySlot.weapon }, input_action);
    }

    settings.state = GameState.use;

    {
        const event = InputEvent.initChar('z', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.none, input_action);
    }
}

test "input use mode exit" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var input = Input.init(allocator);
    defer input.deinit();
    var settings = Settings.init();
    const time = 0;

    {
        const event = InputEvent.initChar('z', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .startUseItem = InventorySlot.weapon }, input_action);
    }

    settings.state = GameState.use;

    {
        const event = InputEvent.initChar('z', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.none, input_action);
    }

    {
        const event = InputEvent.initChar('4', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .useDir = Direction.left }, input_action);
    }

    {
        const event = InputEvent.initChar('4', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.finalizeUse, input_action);
    }
}

test "input use mode abort" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var input = Input.init(allocator);
    defer input.deinit();
    var settings = Settings.init();
    const time = 0;

    {
        const event = InputEvent.initChar('z', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction{ .startUseItem = InventorySlot.weapon }, input_action);
    }

    settings.state = GameState.use;

    {
        const event = InputEvent.initChar(' ', KeyDir.down);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.abortUse, input_action);
    }

    settings.state = GameState.playing;

    {
        const event = InputEvent.initChar('4', KeyDir.up);
        const input_action = try input.handleEvent(event, &settings, time);
        try std.testing.expectEqual(InputAction.none, input_action);
    }
}
