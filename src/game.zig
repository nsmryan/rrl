const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const Level = core.level.Level;
const MoveMode = core.movement.MoveMode;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

const events = @import("events");
const UseAction = events.input.UseAction;

pub const Game = struct {
    level: Level,
    rng: Random,

    pub fn init(rng: Random, allocator: Allocator) Game {
        return Game{ .level = Level.empty(allocator), .rng = rng };
    }

    pub fn deinit(self: *Game) void {
        self.level.deinit();
    }
};

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
    use_dir: ?Direction,
    move_mode: MoveMode = MoveMode.walk,
    debug_enabled: bool = false,
    map_load_config: MapLoadConfig,
    map_changed: bool = false,
    exit_condition: LevelExitCondition = LevelExitCondition.rightEdge,

    pub fn init() Settings {
        return Settings{};
    }

    pub fn is_cursor_mode(self: *Settings) bool {
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
