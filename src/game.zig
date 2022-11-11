const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const RndGen = std.rand.DefaultPrng;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const Level = core.level.Level;
const MoveMode = core.movement.MoveMode;
const Config = core.config.Config;
const movement = core.movement;
const Stance = core.entities.Stance;

const board = @import("board");
const Map = board.map.Map;
const Tile = board.tile.Tile;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

pub const actions = @import("game/actions.zig");
pub const input = @import("game/input.zig");
const Input = input.Input;
const UseAction = actions.UseAction;
const InputAction = actions.InputAction;
const InputEvent = input.InputEvent;

pub const resolve = @import("game/resolve.zig");

pub const messaging = @import("game/messaging.zig");
pub const MsgLog = messaging.MsgLog;

const CONFIG_PATH = "data/config.txt";

pub const Game = struct {
    level: Level,
    rng: RndGen,
    input: Input,
    config: Config,
    settings: Settings,
    log: MsgLog,

    pub fn init(seed: ?u64, allocator: Allocator) !Game {
        var rng = RndGen.init(seed orelse 0);
        const config = try Config.fromFile(CONFIG_PATH[0..]);
        var level = Level.empty(allocator);

        // Always spawn a player entity even if there is nothing else in the game.
        try core.spawn.spawnPlayer(&level.entities, &config);

        return Game{
            .level = level,
            .rng = rng,
            .input = Input.init(allocator),
            .config = config,
            .settings = Settings.init(),
            .log = MsgLog.init(allocator),
        };
    }

    pub fn deinit(game: *Game) void {
        game.level.deinit();
        game.log.deinit();
    }

    pub fn step(game: *Game, input_event: InputEvent, ticks: u64) !void {
        const input_action = try game.input.handleEvent(input_event, &game.settings, ticks);
        std.log.debug("input {any}", .{input_action});
        game.handleInputAction(input_action);
    }

    pub fn handleInputAction(game: *Game, input_action: InputAction) !void {
        try actions.resolveAction(game, input_action);
        try resolve.resolve(game);
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

test "init and deinit game" {
    var game = try Game.init(0, std.testing.allocator);
    game.deinit();
}

test "walk around a bit" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    game.level.map = try Map.fromDims(3, 3, allocator);

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(1, 0), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 1), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0).?);
}

test "walk into full tile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    game.level.map = try Map.fromDims(3, 3, allocator);
    game.level.map.set(Pos.init(1, 1), Tile.impassable());

    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0).?);

    game.level.map.set(Pos.init(1, 0), Tile.tallWall());

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0).?);

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0).?);
}

test "run around" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    game.level.map = try Map.fromDims(3, 3, allocator);

    game.level.entities.pos.set(0, Pos.init(0, 0));

    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0).?);

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 2), game.level.entities.pos.get(0).?);
}

test "interact with intertile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    game.level.map = try Map.fromDims(3, 3, allocator);
    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0).?);

    // Try to walk past wall diagonally- should succeed
    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0).?);

    // Try to walk back past wall diagonally- should succeed
    try game.handleInputAction(InputAction{ .move = .upLeft });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0).?);

    // Run
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0).?);

    // Jump over wall
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0).?);

    // Sneak
    try game.handleInputAction(InputAction.sneak);
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0).?);

    // Can't jump over wall
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0).?);
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0).?);

    // Pass turn to change stance
    try game.handleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.standing, game.level.entities.stance.get(0).?);

    try game.handleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.crouching, game.level.entities.stance.get(0).?);

    // Run again
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0).?);

    // Try to run over wall- should fail because crouched from sneaking.
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0).?);
}

test "interact with intertile corners" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    game.level.entities.pos.set(0, Pos.init(1, 1));

    game.level.map = try Map.fromDims(3, 3, allocator);
    game.level.map.set(Pos.init(1, 1), Tile.shortLeftAndDownWall());

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0).?);

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .left });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0).?);

    // Try to walk past wall diagonally- should fail
    try game.handleInputAction(InputAction{ .move = .downLeft });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0).?);

    // Try to walk past wall diagonally in other direction- should fail
    game.level.entities.pos.set(0, Pos.init(2, 2));
    try game.handleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0).?);

    // Run
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0).?);

    // Try to run over wall diagonally- should fail
    try game.handleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0).?);

    // Try to run over wall up- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0).?);

    // Try to run over wall right- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0).?);
}
