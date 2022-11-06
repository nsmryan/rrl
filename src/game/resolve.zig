const std = @import("std");

const g = @import("game");
const Game = g.Game;

pub fn resolve(game: *Game) !void {
    while (try game.log.pop()) |msg| {
        switch (msg) {
            .tryMove => |args| {
                std.debug.print("msg {}\n", .{args});
            },
        }
    }
}
