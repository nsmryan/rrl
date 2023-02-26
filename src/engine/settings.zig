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

const Buffer = @import("utils").buffer.Buffer;

const actions = @import("actions.zig");

const use = @import("use.zig");

pub const LevelExitCondition = enum {
    rightEdge,
    keyAndGoal,
};

pub const Mode = union(enum) {
    playing,
    use: struct { pos: ?Pos, use_action: use.UseAction, dir: ?Direction, use_result: ?use.UseResult },
    cursor: struct { pos: Pos, use_action: ?use.UseAction },
};

pub const Settings = struct {
    turn_count: usize = 0,
    test_mode: bool = false,
    map_type: MapGenType = MapGenType.island,
    state: GameState = GameState.playing,
    overlay: bool = false,
    mode: Mode = Mode.playing,

    debug_enabled: bool = false,
    map_load_config: MapLoadConfig = MapLoadConfig.empty,
    map_changed: bool = false,
    exit_condition: LevelExitCondition = LevelExitCondition.rightEdge,

    splash: Buffer(128) = Buffer(128).init(),

    pub fn init() Settings {
        return Settings{};
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
    splash,

    pub fn isMenu(self: GameState) bool {
        return self == .inventory or
            self == .skillMenu or
            self == .confirmQuit or
            self == .helpMenu or
            self == .classMenu;
    }
};
