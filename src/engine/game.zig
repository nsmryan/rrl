const std = @import("std");
const print = std.debug.print;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const RndGen = std.rand.DefaultPrng;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const utils = @import("utils");

const core = @import("core");
const fov = core.fov;
const Level = core.level.Level;
const MoveMode = core.movement.MoveMode;
const Config = core.config.Config;
const movement = core.movement;
const Stance = core.entities.Stance;
const GolemName = core.entities.GolemName;
const Entities = core.entities.Entities;
const items = core.items;

const board = @import("board");
const Map = board.map.Map;
const Tile = board.tile.Tile;
const FovResult = board.blocking.FovResult;
const FloodFill = board.floodfill.FloodFill;

pub const actions = @import("actions.zig");
pub const input = @import("input.zig");
const Input = input.Input;
const InputAction = actions.InputAction;
const InputEvent = input.InputEvent;

pub const resolve = @import("resolve.zig");

pub const messaging = @import("messaging.zig");
pub const MsgLog = messaging.MsgLog;
pub const Msg = messaging.Msg;

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
        try game.inputEvent(input_event, ticks);
        try game.resolveMessages();

        // If there are no new messages, and the player took their turn,
        // log the end turn message and resolve it, return this message as the result.
        // The next call to this function will return null, indicating the end of the messages.
        const player_took_turn = game.level.entities.turn.get(Entities.player_id).any();
        if (player_took_turn) {
            for (game.level.entities.behavior.ids.items) |id| {
                // Only step entities that:
                //   have a behavior
                //   are currently active
                //   are in the play state
                //   are not currently frozen
                if (game.level.entities.status.get(id).active and
                    game.level.entities.state.get(id) == .play and
                    game.level.entities.status.get(id).frozen == 0)
                {
                    try game.log.log(.aiStep, id);
                    try game.resolveMessages();

                    // Clear perception - the golem has already acted on this perception at this point.
                    game.level.entities.percept.getPtr(id).* = .none;
                }
            }

            try game.log.log(.endTurn, .{});
            try game.resolveMessages();
        }
    }

    pub fn inputEvent(game: *Game, input_event: InputEvent, ticks: u64) !void {
        game.log.clear();
        const input_action = try game.input.handleEvent(input_event, &game.settings, ticks);
        try game.handleInputAction(input_action);
    }

    pub fn removeMarkedEntities(game: *Game) !void {
        var index: usize = 0;
        while (index < game.level.entities.ids.items.len) {
            const id = game.level.entities.ids.items[index];
            if (game.level.entities.state.get(id) == .remove) {
                game.level.entities.remove(id);
                try game.log.log(.remove, id);
            } else {
                index += 1;
            }
        }
    }

    pub fn handleInputAction(game: *Game, input_action: InputAction) !void {
        if (input_action != .none) {
            try game.removeMarkedEntities();
        }

        try actions.resolveAction(game, input_action);
    }

    pub fn fullyHandleInputAction(game: *Game, input_action: InputAction) !void {
        try game.handleInputAction(input_action);
        try game.resolveMessages();
    }

    pub fn resolveMessage(game: *Game) !?Msg {
        if (try game.log.pop()) |msg| {
            try resolve.resolveMsg(game, msg);
            return msg;
        }

        return null;
    }

    pub fn resolveMessages(game: *Game) !void {
        while (try game.resolveMessage() != null) {}
    }

    pub fn changeState(game: *Game, new_state: GameState) void {
        game.settings.state = new_state;
        if (new_state == .playing) {
            game.settings.mode = .playing;
        }
    }

    pub fn startLevel(game: *Game, width: i32, height: i32) !void {
        game.level.map.deinit();
        game.level.map = try Map.fromDims(width, height, game.allocator);

        try game.log.log(.newLevel, .{});

        // NOTE(implement) carry over energy and health as per spreadsheet.
        // NOTE(implement) carry over skills/talents/items as per spreadsheet.
        try spawn.spawnPlayer(&game.level.entities, &game.log, &game.config, game.allocator);

        // NOTE(remove) this is just for testing
        var id: utils.comp.Id = undefined;
        const spawn_items = [_]items.Item{ .sword, .stone, .hammer, .seedOfStone, .smokeBomb, .dagger, .shield, .khopesh, .axe, .sling, .spear };
        var index: usize = 0;
        for (spawn_items) |item| {
            id = try spawn.spawnItem(&game.level.entities, item, &game.log, &game.config, game.allocator);
            try game.log.log(.move, .{ id, .blink, .walk, Pos.init(@intCast(i32, index), 0) });
            index += 1;
        }

        id = try spawn.spawnGolem(&game.level.entities, &game.config, Pos.init(1, 3), .gol, &game.log, game.allocator);
        try game.log.log(.facing, .{ id, .right });

        try game.log.log(.startLevel, .{});
    }

    pub fn reloadConfig(game: *Game) void {
        game.config = Config.fromFile(CONFIG_PATH[0..]) catch return;
    }

    pub fn sound(game: Game, pos: Pos, amount: usize) !FloodFill {
        var floodfill = FloodFill.init(game.allocator);
        floodfill.dampen_tile_blocked = game.config.dampen_blocked_tile;
        floodfill.dampen_short_wall = game.config.dampen_short_wall;
        floodfill.dampen_tall_wall = game.config.dampen_tall_wall;
        try floodfill.fill(&game.level.map, pos, amount);
        return floodfill;
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
    try game.resolveMessages();

    try game.fullyHandleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(1, 0), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 0), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 1), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));
}

test "walk into full tile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

    game.level.map.set(Pos.init(1, 1), Tile.impassable());

    try game.fullyHandleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    game.level.map.set(Pos.init(1, 0), Tile.tallWall());

    try game.fullyHandleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
}

test "run around" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

    game.level.entities.pos.set(0, Pos.init(0, 0));

    try game.fullyHandleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 2), game.level.entities.pos.get(0));
}

test "run blocked" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());
    game.level.map.set(Pos.init(0, 1), Tile.tallWall());

    game.level.entities.pos.set(0, Pos.init(0, 0));

    try game.fullyHandleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Can't run into blocked tile
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Can't even run into short wall tile
    game.level.map.set(Pos.init(0, 1), Tile.shortWall());
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Not even if there is no intertile wall
    game.level.map.set(Pos.init(0, 0), Tile.empty());
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));
}

test "interact with intertile wall" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

    game.level.map.set(Pos.init(0, 0), Tile.shortDownWall());

    // Try to walk into wall- should fail.
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally- should succeed
    try game.fullyHandleInputAction(InputAction{ .move = .downRight });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk back past wall diagonally- should succeed
    try game.fullyHandleInputAction(InputAction{ .move = .upLeft });
    try std.testing.expectEqual(Pos.init(0, 0), game.level.entities.pos.get(0));

    // Run
    try game.fullyHandleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Jump over wall
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));

    // Sneak
    try game.fullyHandleInputAction(InputAction.sneak);
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0));

    // Can't jump over wall
    try game.fullyHandleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
    try std.testing.expectEqual(MoveMode.sneak, game.level.entities.next_move_mode.get(0));

    // Pass turn to change stance
    try game.fullyHandleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.standing, game.level.entities.stance.get(0));

    try game.fullyHandleInputAction(InputAction.pass);
    try std.testing.expectEqual(Stance.crouching, game.level.entities.stance.get(0));

    // Run again
    try game.fullyHandleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Try to run over wall- should fail because crouched from sneaking.
    try game.fullyHandleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(0, 1), game.level.entities.pos.get(0));
}

test "interact with intertile corners" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

    game.level.map.set(Pos.init(1, 1), Tile.shortLeftAndDownWall());

    game.level.entities.pos.set(0, Pos.init(1, 1));

    // Try to walk into wall- should fail.
    try game.fullyHandleInputAction(InputAction{ .move = .down });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk into wall- should fail.
    try game.fullyHandleInputAction(InputAction{ .move = .left });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally- should fail
    try game.fullyHandleInputAction(InputAction{ .move = .downLeft });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to walk past wall diagonally in other direction- should fail
    game.level.entities.pos.set(0, Pos.init(2, 2));
    try game.fullyHandleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    // Run
    try game.fullyHandleInputAction(InputAction.run);
    try std.testing.expectEqual(MoveMode.run, game.level.entities.next_move_mode.get(0));

    // Try to run over wall diagonally- should fail
    try game.fullyHandleInputAction(InputAction{ .move = .upRight });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));

    // Try to run over wall up- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.fullyHandleInputAction(InputAction{ .move = .up });
    try std.testing.expectEqual(Pos.init(1, 1), game.level.entities.pos.get(0));

    // Try to run over wall right- should succeed
    game.level.entities.pos.set(0, Pos.init(1, 2));
    try game.fullyHandleInputAction(InputAction{ .move = .right });
    try std.testing.expectEqual(Pos.init(2, 2), game.level.entities.pos.get(0));
}

test "basic level fov" {
    const allocator = std.testing.allocator;

    var game = try Game.init(0, allocator);
    defer game.deinit();

    try game.startLevel(3, 3);
    try game.resolveMessages();

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
    try game.resolveMessages();

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
    try game.resolveMessages();

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

    try game.fullyHandleInputAction(InputAction{ .move = Direction.down });
    try std.testing.expectEqual(FovResult.outside, try game.level.posInFov(Entities.player_id, Pos.init(2, 0)));
}
