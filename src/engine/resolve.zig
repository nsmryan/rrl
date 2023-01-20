const std = @import("std");

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const utils = @import("utils");
const Id = utils.comp.Id;

const board = @import("board");
const Material = board.tile.Tile.Material;
const Height = board.tile.Tile.Height;
const Wall = board.tile.Tile.Wall;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const ItemClass = core.items.ItemClass;
const MoveMode = core.movement.MoveMode;
const Level = core.level.Level;
const Stance = core.entities.Stance;
const Type = core.entities.Type;
const MoveType = core.movement.MoveType;

const messaging = @import("messaging.zig");
const Msg = messaging.Msg;
const MsgType = messaging.MsgType;

const g = @import("game.zig");
const Game = g.Game;

pub fn resolve(game: *Game) !void {
    while (try game.log.pop()) |msg| {
        try resolveMsg(game, msg);
    }
}

pub fn resolveMsg(game: *Game, msg: Msg) !void {
    switch (msg) {
        .tryMove => |args| try resolveTryMove(args.id, args.dir, args.amount, game),
        .move => |args| try resolveMove(args.id, args.move_type, args.move_mode, args.pos, game),
        .gainEnergy => |args| resolveGainEnergy(args.id, args.amount, game),
        .nextMoveMode => |args| resolveNextMoveMode(args.id, args.move_mode, game),
        .pass => |args| try resolvePassTurn(args, game),
        .stance => |args| resolveStance(args.id, args.stance, game),
        .startLevel => try resolveStartLevel(game),
        .endTurn => try resolveEndTurn(game),
        else => {},
    }
}

// NOTE the use of recursion here with resolveMsg results in an error inferring error sets.
//pub fn resolveRightNow(game: *Game, comptime msg_type: MsgType, args: anytype) @typeInfo(@typeInfo(@TypeOf(resolveMsg)).Fn.return_type).ErrorUnion.error_set!void {
//    // Resolve a message immediately. First create the message, append it to the log
//    // as if it was already processed, and then execute its effect.
//    const msg = Msg.genericMsg(msg_type, args);
//    try game.log.all.append(msg);
//    try resolveMsg(game, msg);
//}

fn resolveTryMove(id: Id, dir: Direction, amount: usize, game: *Game) !void {
    // NOTE if this does happen, consider making amount == 0 a Msg.pass.
    std.debug.assert(amount > 0);

    const move_mode = game.level.entities.next_move_mode.get(id);

    const start_pos = game.level.entities.pos.get(id);
    const move_pos = dir.move(start_pos);

    game.level.entities.move_mode.set(id, move_mode);
    const collision = game.level.checkCollision(start_pos, dir);

    // NOTE handle blink and Misc move types as well.
    if (collision.hit()) {
        const stance = game.level.entities.stance.get(id);
        const can_jump = move_mode == MoveMode.run and stance != Stance.crouching;
        const jumpable_wall = collision.wall != null and !collision.wall.?.blocked_tile and collision.wall.?.height == .short;
        const jumped_wall = jumpable_wall and can_jump;

        if (jumped_wall) {
            // NOTE land roll flag could be checks to move one more tile here. Generate another move msg.
            try game.log.now(.jumpWall, .{ id, start_pos, move_pos });
            try game.log.now(.move, .{ id, MoveType.jumpWall, move_mode, move_pos });
        } else {
            // We hit a wall. Generate messages about this, but don't move the entity.
            try game.log.now(.faceTowards, .{ id, move_pos });
            try game.log.now(.collided, .{ id, move_pos });
        }
    } else {
        // No collision, just move to location.
        try game.log.now(.move, .{ id, MoveType.move, move_mode, move_pos });
        if (amount > 1) {
            try game.log.now(.tryMove, .{ id, dir, amount - 1 });
        }
    }
}

fn resolveMove(id: Id, move_type: MoveType, move_mode: MoveMode, pos: Pos, game: *Game) !void {
    const start_pos = game.level.entities.pos.get(id);

    game.level.entities.pos.set(id, pos);
    try game.level.updateFov(id);
    const changed_pos = !std.meta.eql(start_pos, pos);

    if (move_mode == MoveMode.run) {
        game.level.entities.turn.getPtr(id).*.run = true;
    } else {
        game.level.entities.turn.getPtr(id).*.walk = true;
    }

    // TODO if not blink, monsters make a sound
    // TODO item move to position makes a sound unless its the entities position
    // TODO update stance
    // TODO make sound based on tile
    if (move_type != MoveType.blink) {
        if (changed_pos and game.level.entities.typ.get(id) == Type.enemy) {
            try game.log.now(.sound, .{ id, start_pos, game.config.sound_radius_monster });
            try game.log.now(.sound, .{ id, pos, game.config.sound_radius_monster });
        } else if (game.level.entities.typ.get(id) == Type.item) {
            // Dropping the item at your feet is silent. Other item movements make a sound.
            if (changed_pos) {
                try game.log.now(.sound, .{ id, pos, game.config.sound_radius_stone });
            }
        } else {
            // Only normal movements update the stance. Others like Blink leave it as-is.
            if (move_type != MoveType.blink and move_type != MoveType.misc) {
                if (game.level.entities.stance.getOrNull(id)) |stance| {
                    const new_stance = updateStance(move_type, move_mode, stance);

                    try game.log.record(.stance, .{ id, new_stance });
                    resolveStance(id, new_stance, game);
                }
            }

            // Make a noise based on how fast the entity is moving and the terrain.
            if (changed_pos) {
                try makeMoveSound(id, start_pos, pos, move_mode, game);
            }
        } // NOTE other entities do not make sounds on movement, such as items
    }

    // This is cleared in the start of the next turn when the game is stepped.
    game.level.entities.turn.getPtr(id).*.blink = move_type == MoveType.blink;

    // Check if player walks on energy.
    if (id == core.entities.Entities.player_id) {
        for (game.level.entities.ids.items) |entity_id| {
            if (game.level.entities.pos.get(entity_id).eql(pos) and
                game.level.entities.typ.get(entity_id) == Type.energy)
            {
                game.level.entities.markForRemoval(entity_id);

                try game.log.rightNow(.gainEnergy, .{ id, 1 });
            }
        }
    }

    // Resolve traps.
    // NOTE(implement) triggering traps
    //if (start_pos != pos) {
    //    resolveTriggeredTraps(id, start_pos, game);
    //}

    // NOTE(implement) hammer swing
    // check for passing turn while the hammer is raised
    //if (move_type == MoveType.pass) {
    //    if let Some((item_id, dir, turns)) = level.entities.status[&id].hammer_raised {
    //        if turns == 0 {
    //            let hit_pos = dir.offset_pos(start_pos, 1);
    //            game.log.log(Msg::HammerSwing(id, item_id, hit_pos));
    //            level.entities.status[&id].hammer_raised = None;
    //        }
    //    }
    //}

    // Check if we trampled any grass.
    // This only happens for non-item moves that change position, and are not teleports.
    if (!game.level.entities.item.has(id)) {
        if (!start_pos.eql(pos) and move_type != MoveType.blink) {
            trampleGrassWalls(&game.level, start_pos, pos);
        }
    }

    // NOTE(implement) this was used to stop grass from blocking sight when you step on it.
    // Remove this note if this can be done a different way or removed.
    //if (level.map.get(pos).block_sight and level.map.get(pos).material == Material.grass) {
    //    level.map.get(pos).block_sight = false;
    //}

    // NOTE(implement) face monsters towards the player if they enter the monster's line of sight.
    // Another way to do this is notify the monster, and let them turn on their turn.
    // if entity is a monster, which is also alert, and there is a path to the player,
    // then face the player
    //if (level.entities.target(id)) |target_pos| {
    //    if (level.couldSee(id, target_pos, config)) {
    //        game.log.now(.faceTowards, .{ id, target_pos });
    //    }
    //} else {
    //    const dir = Direction.fromPositions(original_pos, pos);
    //    game.log.log_front(.setFacing, .{id, dir});
    //}
    if (Direction.fromPositions(start_pos, pos)) |dir| {
        try game.log.now(.facing, .{ id, dir });
    }

    // NOTE(implement) player steps out of visiblilty. Uses the entity message system right now,
    // which may be better off replaced.
    // For blinking movements, check if the entity disappears from the perspective of an entity.
    //if (move_type == MoveType.blink) {
    //    for (game.level.entities.behavior.ids.items) |id| {
    //        if (game.level.entities.behavior.get(behave_id) == Behavior.attacking(id)) {
    //            game.level.entities.messages.get(behave_id).append(Message.disappeared(id));
    //        }
    //    }
    //}
}

pub fn makeMoveSound(id: Id, original_pos: Pos, pos: Pos, move_mode: MoveMode, game: *Game) !void {
    var sound_radius = switch (move_mode) {
        MoveMode.sneak => game.config.sound_radius_sneak,
        MoveMode.walk => game.config.sound_radius_walk,
        MoveMode.run => game.config.sound_radius_run,
    };

    const surface = game.level.map.get(pos).center.material;
    if (surface == Material.rubble) {
        // If the entity has no passives, or they do but are not sure footed.
        // NOTE(implement) passive for sure footed implemented here. Instead always use rubble radius for now.
        //if (game.level.entities.passive.get(&id).is_none() or !level.entities.passive.get(id).sure_footed) {
        //    sound_radius += config.sound_rubble_radius;
        //}
        sound_radius += game.config.sound_rubble_radius;
    } else if (surface == Material.grass) {
        sound_radius -= game.config.sound_grass_radius;
    }

    // NOTE(implement) status and passive for softer steps implemented here.
    //if (sound_radius > 0 and game.level.entities.status.get(id).soft_steps > 0) {
    //    sound_radius -= 1;
    //}

    //if (sound_radius > 0 and game.level.entities.passive.get(id).soft_shoes) {
    //    sound_radius -= 1;
    //}

    try game.log.now(.sound, .{ id, pos, sound_radius });
    try game.log.now(.sound, .{ id, original_pos, sound_radius });
}

pub fn updateStance(move_type: MoveType, move_mode: MoveMode, stance: Stance) Stance {
    var new_stance = stance;

    if (move_type == MoveType.pass and move_mode != MoveMode.sneak) {
        new_stance = Stance.standing;
    } else if (move_type == MoveType.pass) {
        new_stance = stance.waited(move_mode);
    } else if (move_mode == MoveMode.run) {
        new_stance = Stance.running;
    } else if (move_mode == MoveMode.sneak) {
        new_stance = Stance.crouching;
    } else if (move_mode == MoveMode.walk) {
        new_stance = Stance.standing;
    }

    return new_stance;
}

test "test update stance" {
    try std.testing.expectEqual(Stance.crouching, updateStance(MoveType.pass, MoveMode.sneak, Stance.standing));
    try std.testing.expectEqual(Stance.crouching, updateStance(MoveType.move, MoveMode.sneak, Stance.standing));
    try std.testing.expectEqual(Stance.standing, updateStance(MoveType.pass, MoveMode.walk, Stance.crouching));
    try std.testing.expectEqual(Stance.standing, updateStance(MoveType.pass, MoveMode.walk, Stance.standing));
    try std.testing.expectEqual(Stance.running, updateStance(MoveType.move, MoveMode.run, Stance.standing));
    try std.testing.expectEqual(Stance.running, updateStance(MoveType.move, MoveMode.run, Stance.crouching));
}

fn resolveGainEnergy(id: Id, amount: u32, game: *Game) void {
    game.level.entities.energy.getPtr(id).* += amount;
}

// NOTE(implement) trap triggering
//fn resolveTriggeredTraps(id: EntityId, start_pos: Pos, game) !void {
//    // Check for light touch first, in case it prevents a trap from triggering.
//    if (level.entities.passive.get(id)) |passive| {
//       if (passive.light_touch and rng_trial(rng, 0.5)) {
//            return;
//       }
//    }
//
//    // TODO convert to checking for traps instead of allocating an array.
//    for (game.level.entities.ids) |id| {
//    // get a list of triggered traps
//    let traps: Vec<EntityId> = level.entities.triggered_traps(level.entities.pos[&id]);
//
//    // Check if the entity hit a trap
//    for trap in traps.iter() {
//        match level.entities.trap[trap] {
//            Trap::Spikes => {
//                game.log.log(Msg::SpikeTrapTriggered(*trap, id));
//                level.entities.mark_for_removal(*trap);
//            }
//
//            Trap::Sound => {
//                game.log.log(Msg::SoundTrapTriggered(*trap, id));
//                level.entities.needs_removal[trap] = true;
//                level.entities.mark_for_removal(*trap);
//            }
//
//            Trap::Blink => {
//                game.log.log(Msg::BlinkTrapTriggered(*trap, id));
//                level.entities.mark_for_removal(*trap);
//            }
//
//            Trap::Freeze => {
//                game.log.log(Msg::FreezeTrapTriggered(*trap, id));
//                level.entities.mark_for_removal(*trap);
//            }
//        }
//    }
//
//    // Resolve triggers
//    for key in level.entities.ids.iter() {
//        // key is a trigger
//        if level.entities.typ[key] == Type::Trigger {
//            // stepped on trigger
//           if level.entities.pos[key] == level.entities.pos[&id] {
//               game.log.log_front(Msg::Triggered(*key, id));
//           }
//
//            // stepped off of trigger
//           if level.entities.pos[key] == original_pos &&
//              level.entities.status[key].active {
//               game.log.log_front(Msg::Untriggered(*key, id));
//           }
//        }
//    }
//}

pub fn trampleGrassWalls(level: *Level, start_pos: Pos, end_pos: Pos) void {
    switch (Direction.fromPositions(start_pos, end_pos).?) {
        Direction.left, Direction.right, Direction.up, Direction.down => {
            trampleGrassMove(level, start_pos, end_pos);
        },

        Direction.downLeft, Direction.downRight => {
            trampleGrassMove(level, start_pos, start_pos.moveY(1));
            trampleGrassMove(level, start_pos.moveY(1), end_pos);
        },

        Direction.upLeft, Direction.upRight => {
            trampleGrassMove(level, start_pos, start_pos.moveY(-1));
            trampleGrassMove(level, start_pos.moveY(-1), end_pos);
        },
    }
}

pub fn trampleGrassMove(level: *Level, start_pos: Pos, end_pos: Pos) void {
    var wall_pos: Pos = undefined;
    var is_left_wall: bool = undefined;
    switch (Direction.fromPositions(start_pos, end_pos).?) {
        Direction.left => {
            wall_pos = start_pos;
            is_left_wall = true;
        },

        Direction.right => {
            wall_pos = end_pos;
            is_left_wall = true;
        },

        Direction.up => {
            wall_pos = end_pos;
            is_left_wall = false;
        },

        Direction.down => {
            wall_pos = start_pos;
            is_left_wall = false;
        },

        else => {
            std.debug.panic("Trampling a grass wall on a diagonal isn't possible!", .{});
        },
    }

    var material: Material = undefined;
    if (is_left_wall) {
        material = level.map.get(wall_pos).left.material;
    } else {
        material = level.map.get(wall_pos).down.material;
    }

    if (material == Material.grass) {
        if (is_left_wall) {
            level.map.getPtr(wall_pos).*.left.material = Material.stone;
            level.map.getPtr(wall_pos).*.left.height = Height.empty;
        } else {
            level.map.getPtr(wall_pos).*.down.material = Material.stone;
            level.map.getPtr(wall_pos).*.down.height = Height.empty;
        }
    }
}

fn resolveNextMoveMode(id: Id, move_mode: MoveMode, game: *Game) void {
    game.level.entities.next_move_mode.getPtr(id).* = move_mode;
}

fn resolvePassTurn(id: Id, game: *Game) !void {
    game.level.entities.turn.getPtr(id).*.pass = true;

    if (game.level.entities.stance.getOrNull(id)) |stance| {
        const new_stance = updateStance(.pass, game.level.entities.next_move_mode.get(id), stance);
        try game.log.record(.stance, .{ id, new_stance });
        resolveStance(id, new_stance, game);
    }
}

fn resolveStance(id: Id, stance: Stance, game: *Game) void {
    game.level.entities.stance.set(id, stance);
}

fn resolveStartLevel(game: *Game) !void {
    try game.level.updateAllFov();
    game.level.entities.turn.getPtr(core.entities.Entities.player_id).* = core.entities.Turn.init();
}

fn resolveEndTurn(game: *Game) !void {
    game.level.entities.turn.getPtr(core.entities.Entities.player_id).* = core.entities.Turn.init();
}
