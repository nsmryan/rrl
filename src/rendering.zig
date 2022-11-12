const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const Game = engine.game.Game;

const core = @import("core");
const Entities = core.entities.Entities;

const board = @import("board");
const Tile = board.tile.Tile;

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

    try renderMapLow(game, sprites, drawcmds);
    try renderEntities(game, sprites, drawcmds);
    // TODO render map mid level
    // TODO render map upper level
}

fn renderMapLow(game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const open_tile = try drawcmd.sprite.lookupSpritekey(sprites, "open_tile");
    const open_tile_sprite = Sprite.init(0, open_tile);

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);
            if (tile.center.material == Tile.Material.stone) {
                try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), pos));
            }
        }
    }
}

fn renderEntities(game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const pos = game.level.entities.pos.get(Entities.player_id).?;
    const player_tile = try drawcmd.sprite.lookupSpritekey(sprites, "player_standing_right");
    const player_sprite = Sprite.init(0, player_tile);
    try drawcmds.append(DrawCmd.sprite(player_sprite, Color.black(), pos));
}
