const std = @import("std");

const g = @import("game");
const Game = g.Game;

pub fn resolve(game: *Game) !void {
    while (try game.log.pop()) |msg| {
        switch (msg) {
            .tryMove => |args| {
                std.debug.print("msg {}\n", .{args});
                // TODO use level checkCollision.
                // If possible, move.
                // If amount is not 0, add new try move.
                // then implement move itself.
            },
        }
    }
}
