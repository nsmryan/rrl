const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const Game = engine.game.Game;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Panel = drawcmd.panel.Panel;
const Sprites = drawcmd.sprite.Sprites;
const Sprite = drawcmd.sprite.Sprite;
const SpriteSheet = drawcmd.sprite.SpriteSheet;

pub fn render(game: *Game, sprites: *const ArrayList(SpriteSheet), panel: *const Panel, drawcmds: *ArrayList(DrawCmd)) !void {
    _ = panel;
    _ = game;

    const open_tile = try drawcmd.sprite.lookupSpritekey(sprites, "open_tile");
    const open_tile_sprite = Sprite.init(0, open_tile);
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(0, 0)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(0, 1)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(0, 2)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(1, 0)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(1, 1)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(1, 2)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(2, 0)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(2, 1)));
    try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), Pos.init(2, 2)));
    // TODO render map lower level
    // TODO render map mid level
    // TODO render map upper level
}
