const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const Game = engine.game.Game;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Panel = drawcmd.panel.Panel;
const Sprites = drawcmd.sprite.Sprites;
const Sprite = drawcmd.sprite.Sprite;
const SpriteSheet = drawcmd.sprite.SpriteSheet;

pub fn render(game: *Game, sprites: *const ArrayList(SpriteSheet), panel: *const Panel, drawcmds: *ArrayList(DrawCmd)) !void {
    _ = game;
    _ = sprites;
    _ = panel;
    _ = drawcmds;
    // TODO render map lower level
    // TODO render map mid level
    // TODO render map upper level
}
