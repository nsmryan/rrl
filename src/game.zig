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
const InputAction = events.actions.InputAction;
const GameState = events.actions.GameState;
const Settings = events.actions.Settings;

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
