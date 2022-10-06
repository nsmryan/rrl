const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

const core = @import("core");
const Level = core.level.Level;

pub const Game = struct {
    level: Level,
    rng: Random,

    pub fn init(rng: Random, allocator: Allocator) Game {
        return Game{ .level = Level.init(allocator), .rng = rng };
    }

    pub fn deinit(self: *Game) void {
        self.level.deinit();
    }
};
