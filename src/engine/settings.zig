const std = @import("std");

const ArrayList = std.ArrayList;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const core = @import("core");

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

const input = @import("input.zig");

const actions = @import("actions.zig");
const UseAction = actions.UseAction;

pub const LevelExitCondition = enum {
    rightEdge,
    keyAndGoal,
};

pub const Settings = struct {
    turn_count: usize = 0,
    test_mode: bool = false,
    map_type: MapGenType = MapGenType.island,
    state: GameState = GameState.playing,
    overlay: bool = false,
    level_num: usize = 0,
    running: bool = true,
    cursor: ?Pos = null,
    use_action: UseAction = UseAction.interact,
    cursor_action: ?UseAction = null,
    use_dir: ?Direction = null,
    debug_enabled: bool = false,
    map_load_config: MapLoadConfig = MapLoadConfig.empty,
    map_changed: bool = false,
    exit_condition: LevelExitCondition = LevelExitCondition.rightEdge,

    pub fn init() Settings {
        return Settings{};
    }

    pub fn isCursorMode(self: *const Settings) bool {
        return self.cursor != null;
    }
};

pub const GameState = enum {
    playing,
    win,
    lose,
    inventory,
    skillMenu,
    classMenu,
    helpMenu,
    confirmQuit,
    use,
    exit,

    pub fn isMenu(self: GameState) bool {
        return self == .inventory or
            self == .skillMenu or
            self == .confirmQuit or
            self == .helpMenu or
            self == .classMenu;
    }
};
