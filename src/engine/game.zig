const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const RndGen = std.rand.DefaultPrng;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const fov = core.fov;
const Level = core.level.Level;
const MoveMode = core.movement.MoveMode;
const Config = core.config.Config;
const movement = core.movement;
const Stance = core.entities.Stance;
const Entities = core.entities.Entities;

const board = @import("board");
const Map = board.map.Map;
const Tile = board.tile.Tile;
const FovResult = board.blocking.FovResult;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

pub const actions = @import("actions.zig");
pub const input = @import("input.zig");
const Input = input.Input;
const UseAction = actions.UseAction;
const InputAction = actions.InputAction;
const InputEvent = input.InputEvent;

pub const resolve = @import("resolve.zig");

pub const messaging = @import("messaging.zig");
pub const MsgLog = messaging.MsgLog;

pub const s = @import("settings.zig");
pub const GameState = s.GameState;
pub const Settings = s.Settings;

pub const spawn = @import("spawn.zig");

const CONFIG_PATH = "data/config.txt";

pub const Game = struct {
    level: Level,
    rng: RndGen,
    input: Input,
    config: Config,
    settings: Settings,
    log: MsgLog,
    allocator: Allocator,

    pub fn init(seed: u64, allocator: Allocator) !Game {
        var rng = RndGen.init(seed);
        const config = try Config.fromFile(CONFIG_PATH[0..]);
        var level = Level.empty(allocator);
        var log = MsgLog.init(allocator);

        return Game{
            .level = level,
            .rng = rng,
            .input = Input.init(allocator),
            .config = config,
            .settings = Settings.init(),
            .log = log,
            .allocator = allocator,
        };
    }

    pub fn deinit(game: *Game) void {
        game.level.deinit();
        game.log.deinit();
    }

    pub fn step(game: *Game, input_event: InputEvent, ticks: u64) !void {
        game.log.clear();
        const input_action = try game.input.handleEvent(input_event, &game.settings, ticks);
        try game.handleInputAction(input_action);
    }

    pub fn handleInputAction(game: *Game, input_action: InputAction) !void {
        try actions.resolveAction(game, input_action);
        try resolve.resolve(game);
        try game.log.record(.endTurn, .{});
    }

    pub fn changeState(game: *Game, new_state: GameState) void {
        game.settings.state = new_state;
    }

    pub fn startLevel(game: *Game, width: i32, height: i32) !void {
        game.level.map.deinit();
        game.level.map = try Map.fromDims(width, height, game.allocator);

        try game.log.log(.newLevel, .{});

        // NOTE(implement) carry over energy and health as per spreadsheet.
        // NOTE(implement) carry over skills/talents/items as per spreadsheet.
        try spawn.spawnPlayer(&game.level.entities, &game.log, &game.config, game.allocator);

        try game.log.log(.startLevel, .{});

        try resolve.resolve(game);
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

    try game.startLevel(3, 3);

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(1, 0), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 1), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));
}

test "walk into full tile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(1, 1), Tile.impassable());

    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    game.level.map.set(Pos.init(1, 0), Tile.tallWall());

    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
}

test "run around" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.entities.pos.set(0, Pos.init(0, 0));

    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 2), game.level.entities.pos.get(0));
}

test "run blocked" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());
    game.level.map.set(Pos.init(0, 1), Tile.tallWall());

    game.level.entities.pos.set(0, Pos.init(0, 0));

    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Can't run into blocked tile
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Can't even run into short wall tile
    game.level.map.set(Pos.init(0, 1), Tile.shortWall());
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Not even if there is no intertile wall
    game.level.map.set(Pos.init(0, 0), Tile.empty());
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));
}

test "interact with intertile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally- should succeed
    try game.handleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk back past wall diagonally- should succeed
    try game.handleInputAction(InputAction{ .move = .upLeft });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Run
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Jump over wall
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));

    // Sneak
    try game.handleInputAction(InputAction.sneak);
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0));

    // Can't jump over wall
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0));

    // Pass turn to change stance
    try game.handleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.standing, game.level.entities.stance.get(0));

    try game.handleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.crouching, game.level.entities.stance.get(0));

    // Run again
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Try to run over wall- should fail because crouched from sneaking.
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
}

test "interact with intertile corners" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(1, 1), Tile.shortLeftAndDownWall());

    game.level.entities.pos.set(0, Pos.init(1, 1));

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk into wall- should fail.
    try game.handleInputAction(InputAction{ .move = .left });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally- should fail
    try game.handleInputAction(InputAction{ .move = .downLeft });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally in other direction- should fail
    game.level.entities.pos.set(0, Pos.init(2, 2));
    try game.handleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    // Run
    try game.handleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Try to run over wall diagonally- should fail
    try game.handleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    // Try to run over wall up- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.handleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to run over wall right- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.handleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));
}

test "basic level fov" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(1, 1), Tile.tallWall());

    game.level.entities.pos.set(0, Pos.init(1, 0));

    // in fov
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(0, 0), .high));
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(1, 0), .high));
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(2, 0), .high));

    // out of fov
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(1, 2), .high));
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(1, 3), .high));
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(1, 4), .high));
}

test "short wall level fov" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());

    game.level.entities.pos.set(0, Pos.init(0, 0));

    // in fov
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(0, 0), .high));
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(1, 0), .high));
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(2, 0), .high));

    // In fov when standing
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(0, 1), .high));
    try std.testing.expect(try fov.fovCheck(&game.level, 0, Pos.init(0, 2), .high));

    // out of fov when crouching
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(0, 1), .low));
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(0, 2), .low));
    try std.testing.expect(!try fov.fovCheck(&game.level, 0, Pos.init(0, 3), .low));
}

test "basic level fov" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    game.level.map.set(Pos.init(1, 1), Tile.tallWall());

    game.level.entities.pos.set(Entities.player_id, Pos.init(0, 0));

    try game.level.updateFov(Entities.player_id);

    // The player tile is visible.
    try std.testing.expectEqual(FovResult.inside, try game.level.posInFov(Entities.player_id, Pos.init(0, 0)));

    // The wall tile is visible.
    try std.testing.expectEqual(FovResult.inside, try game.level.posInFov(Entities.player_id, Pos.init(1, 1)));

    // The tile past the wall is not visible.
    try std.testing.expectEqual(FovResult.outside, try game.level.posInFov(Entities.player_id, Pos.init(2, 2)));

    // The fov goes from inside -> edge -> outside
    const fov_radius = game.config.fov_radius_player;
    try std.testing.expectEqual(FovResult.inside, try game.level.posInFov(Entities.player_id, Pos.init(fov_radius, 0)));
    try std.testing.expectEqual(FovResult.edge, try game.level.posInFov(Entities.player_id, Pos.init(fov_radius + 1, 0)));
    try std.testing.expectEqual(FovResult.outside, try game.level.posInFov(Entities.player_id, Pos.init(fov_radius + 2, 0)));

    // Moving updates FoV
    try std.testing.expectEqual(FovResult.inside, try game.level.posInFov(Entities.player_id, Pos.init(2, 0)));

    try game.handleInputAction(InputAction{ .move = Direction.down });
    try std.testing.expectEqual(FovResult.outside, try game.level.posInFov(Entities.player_id, Pos.init(2, 0)));
}
