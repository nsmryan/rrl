const g = @import("game.zig");
const Game = g.Game;

const spawn = @import("spawn.zig");

const core = @import("core");
const MoveType = core.movement.MoveType;
const MoveMode = core.movement.MoveMode;

const board = @import("board");
const Tile = board.tile.Tile;

const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;

pub fn ensureGrass(game: *Game, pos: Pos) !Id {
    game.level.map.getPtr(pos).center.material = .grass;

    var id: Id = undefined;
    if (game.level.entityNameAtPos(pos, .grass)) |grass_id| {
        id = grass_id;
    } else {
        id = try spawn.spawnGrass(&game.level.entities, &game.log);
        try game.log.log(.move, .{ id, MoveType.blink, MoveMode.walk, pos });
    }

    return id;
}

pub fn ensureTallGrass(game: *Game, pos: Pos) !Id {
    const id = try ensureGrass(game, pos);
    game.level.map.set(pos, Tile.tallGrass());
    return id;
}
