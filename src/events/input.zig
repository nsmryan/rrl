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

pub const ActionMode = enum {
    primary,
    alternate,
};

pub const UseAction = union(enum) {
    item: ItemClass,
    skill: struct { skill: Skill, action_mode: ActionMode },
    talent: Talent,
    interact,
};

pub const InputAction = union(enum) {
    run,
    sneak,
    walk,
    alt,
    move: Direction,
    moveTowardsCursor,
    skillPos: struct {
        index: usize,
        pos: Pos,
        action: ActionMode,
    },
    skillFacing: struct {
        index: usize,
        action: ActionMode,
    },
    startUseItem: ItemClass,
    startUseSkill: struct { index: usize, action: ActionMode },
    startUseTalent: usize,
    useDir: Direction,
    finalizeUse,
    abortUse,
    pass,
    throwItem: struct { pos: Pos, item_class: ItemClass },
    pickup,
    dropItem,
    yell,
    cursorMove: struct { dir: Direction, is_relative: bool, is_long: bool },
    cursorReturn,
    cursorToggle,
    mousePos: Pos,
    mouseButton: struct { mouse_click: MouseClick, key_dir: KeyDir },
    inventory,
    skillMenu,
    classMenu,
    helpMenu,
    exit,
    esc,
    forceExit,
    exploreAll,
    regenerateMap,
    testMode,
    overlayToggle,
    selectEntry: usize,
    debugToggle,
    restart,
    none,
};

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

    pub fn handle_event(self: *Input, settings: *Settings, event: InputEvent, ticks: u32, config: *const Config) InputAction {
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
};
