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
const Config = core.config.Config;
const movement = core.movement;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

pub const actions = @import("game/actions.zig");
pub const input = @import("game/input.zig");
const Input = input.Input;
const UseAction = actions.UseAction;
const InputAction = actions.InputAction;
const InputEvent = input.InputEvent;

const CONFIG_PATH = "data/config.txt";

pub const Game = struct {
    level: Level,
    rng: Random,
    input: Input,
    config: Config,
    settings: Settings,

    pub fn init(rng: Random, allocator: Allocator) !Game {
        return Game{
            .level = Level.empty(allocator),
            .rng = rng,
            .input = Input.init(allocator),
            .config = try Config.fromFile(CONFIG_PATH[0..]),
            .settings = Settings.init(),
        };
    }

    pub fn deinit(game: *Game) void {
        game.level.deinit();
    }

    pub fn step(game: *Game, input_event: InputEvent, ticks: u64) !void {
        const input_action = try game.input.handleEvent(input_event, &game.settings, ticks);
        std.log.debug("input {any}\n", .{input_action});
        actions.resolveAction(game, input_action);
    }

    pub fn changeState(game: *Game, new_state: GameState) void {
        game.settings.state = new_state;
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
    use_dir: ?Direction = null,
    move_mode: movement.MoveMode = movement.MoveMode.walk,
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

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
