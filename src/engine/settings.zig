const std = @import("std");
const BoundedArray = std.BoundedArray;

const ArrayList = std.ArrayList;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const core = @import("core");

const input = @import("input.zig");

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

pub const MapLoadConfig = union(enum) {
    random,
    testMap,
    testWall,
    testColumns,
    empty,
    testSmoke,
    testCorner,
    testPlayer,
    testArmil,
    testVaults,
    testTraps,
    vaultFile: []u8,
    procGen: []u8,
    testGen: []u8,
};

pub const Settings = struct {
    turn_count: usize = 0,
    state: GameState = GameState.playing,
    overlay: bool = false,
    mode: Mode = Mode.playing,

    debug_enabled: bool = false,
    map_load_config: MapLoadConfig = MapLoadConfig.empty,
    map_changed: bool = false,
    exit_condition: LevelExitCondition = LevelExitCondition.rightEdge,

    splash: BoundedArray(u8, 128) = BoundedArray(u8, 128).init(0) catch unreachable,

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
