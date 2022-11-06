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

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

const events = @import("events");
const Input = events.input.Input;
const UseAction = events.input.UseAction;
const InputAction = events.actions.InputAction;
const GameState = events.actions.GameState;
const Settings = events.actions.Settings;
const InputEvent = events.input.InputEvent;

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
        events.actions.resolveAction(game, input_action);
    }

    pub fn changeState(game: *Game, new_state: GameState) void {
        game.settings.state = new_state;
    }
};

pub const LevelExitCondition = enum {
    rightEdge,
    keyAndGoal,
};

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
