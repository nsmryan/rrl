const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const utils = @import("utils");
const Id = utils.comp.Id;

const board = @import("board");
const Material = board.tile.Tile.Material;
const Height = board.tile.Tile.Height;
const Wall = board.tile.Tile.Wall;
const Tile = board.tile.Tile;
const blocking = board.blocking;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const ItemClass = core.items.ItemClass;
const WeaponType = core.items.WeaponType;
const AttackStyle = core.items.AttackStyle;
const MoveMode = core.movement.MoveMode;
const Level = core.level.Level;
const Stance = core.entities.Stance;
const Behavior = core.entities.Behavior;
const Percept = core.entities.Percept;
const Type = core.entities.Type;
const MoveType = core.movement.MoveType;
const Attack = core.movement.Attack;

const messaging = @import("messaging.zig");
const Msg = messaging.Msg;
const MsgType = messaging.MsgType;

const g = @import("game.zig");
const Game = g.Game;

const ai = @import("ai.zig");

const spawn = @import("spawn.zig");
const make_map = @import("make_map.zig");

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
        .pickup => |args| try resolvePickup(game, args),
        .dropItem => |args| try resolveDropItem(game, args.id, args.item_id, args.slot),
        .droppedItem => |args| try resolveDroppedItem(game, args.id, args.slot),
        .eatHerb => |args| try resolveEatHerb(game, args.id, args.item_id),
        .itemThrow => |args| try resolveItemThrow(game, args.id, args.item_id, args.start, args.end, args.hard),
        .yell => |id| try resolveYell(game, id),
        .facing => |args| try resolveFacing(game, args.id, args.facing),
        .interact => |args| try resolveInteract(game, args.id, args.interact_pos),
        .hammerRaise => |args| try resolveHammerRaise(game, args.id, args.dir),
        .hammerSwing => |args| try resolveHammerSwing(game, args.id, args.pos),
        .hammerHitWall => |args| try resolveHammerHitWall(game, args.id, args.start_pos, args.end_pos, args.dir),
        .crushed => |args| try resolveCrushed(game, args.id, args.pos),
        .aiStep => |args| try resolveAiStep(game, args),
        .behaviorChange => |args| resolveBehaviorChange(game, args.id, args.behavior),
        .sound => |args| try resolveSound(game, args.id, args.pos, args.amount),
        .faceTowards => |args| try resolveFaceTowards(game, args.id, args.pos),
        .hit => |args| try resolveHit(game, args.id, args.start_pos, args.hit_pos, args.weapon_type, args.attack_style),
        .attack => |args| try aiAttack(game, args.id, args.target_id),
        .pickedUp => |args| resolvePickedUp(game, args.id, args.item_id),
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
    try game.level.updateAllFov();
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
    //    game.log.now(.setFacing, .{id, dir});
    //}

    // For teleportations (blink) leave the current facing, and do not set facing for
    // entities without a 'facing' component. Otherwise update facing after move.
    if (move_type != MoveType.blink and game.level.entities.facing.has(id)) {
        if (Direction.fromPositions(start_pos, pos)) |dir| {
            try game.log.now(.facing, .{ id, dir });
        }
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
//               game.log.now(Msg::Triggered(*key, id));
//           }
//
//            // stepped off of trigger
//           if level.entities.pos[key] == original_pos &&
//              level.entities.status[key].active {
//               game.log.now(Msg::Untriggered(*key, id));
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

    // Check for passing turn while the hammer is raised.
    if (game.level.entities.status.get(id).hammer_raised) |dir| {
        const pos = game.level.entities.pos.get(id);
        const hit_pos = dir.offsetPos(pos, 1);
        try game.log.log(.hammerSwing, .{ id, hit_pos });
        game.level.entities.status.getPtr(id).hammer_raised = null;
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
    try game.level.updateAllFov();
}

fn resolvePickup(game: *Game, id: Id) !void {
    const pos = game.level.entities.pos.get(id);

    if (game.level.itemAtPos(pos)) |item_id| {
        const item = game.level.entities.item.get(item_id);

        game.level.entities.status.getPtr(item_id).active = false;

        // If there is an inventory slot available, or there is space to drop the currently held item, pick it up.
        const access = game.level.entities.inventory.get(id).accessByClass(item.class());
        if (access.id == null or try game.level.searchForEmptyTile(pos, 10, game.allocator) != null) {
            // If we dropped an item when picking this one up, log this action.
            if (access.id) |dropped_item_id| {
                try game.log.now(.dropItem, .{ id, dropped_item_id, access.slot });
            }
            try game.log.now(.pickedUp, .{ id, item_id, access.slot });
        } else {
            // Reactivate item if we aren't going to use it.
            game.level.entities.status.getPtr(item_id).active = true;
        }
    }
}

fn resolvePickedUp(game: *Game, id: Id, item_id: Id) void {
    _ = game.level.entities.pickUpItem(id, item_id);
}

fn resolveDroppedItem(game: *Game, item_id: Id, slot: core.items.InventorySlot) !void {
    _ = slot;
    game.level.entities.status.getPtr(item_id).active = true;
}

fn resolveDropItem(game: *Game, id: Id, item_id: Id, slot: core.items.InventorySlot) !void {
    const pos = game.level.entities.pos.get(id);

    // NOTE(perf) ensure using frame allocator.
    if (try game.level.searchForEmptyTile(pos, 10, game.allocator)) |empty_pos| {
        game.level.entities.removeItem(id, item_id);
        try game.log.log(.droppedItem, .{ item_id, slot });
        try game.log.log(.move, .{ item_id, .blink, .walk, empty_pos });
    } else {
        try game.log.log(.dropFailed, .{ id, item_id });
    }
}

fn resolveEatHerb(game: *Game, id: Id, item_id: Id) !void {
    _ = game;
    _ = id;
    _ = item_id;
    // NOTE(implement) eating herb.
}

fn resolveFacing(game: *Game, id: Id, facing: Direction) !void {
    game.level.entities.facing.set(id, facing);
    try game.level.updateAllFov();
}

fn resolveYell(game: *Game, id: Id) !void {
    const position = game.level.entities.pos.get(id);
    game.level.entities.turn.getPtr(id).pass = true;
    try game.log.now(.sound, .{ id, position, game.config.yell_radius });
}

fn resolveItemThrow(game: *Game, id: Id, item_id: Id, start: Pos, end: Pos, hard: bool) !void {
    if (start.eql(end)) {
        @panic("Is it possible to throw an item and have it end where it started? Apparently yes");
    }

    // Get target position in direction of throw.
    const end_pos = math.line.Line.moveTowards(start, end, game.config.player_throw_dist);

    // Get clear tile position, possibly hitting a wall or entity and stopping short.
    const hit_pos = game.level.throwTowards(start, end_pos);

    // If we hit an entity, stop on the entities tile and resolve stunning it.
    if (game.level.blockingEntityAtPos(hit_pos)) |hit_entity| {
        if (game.level.entities.typ.get(hit_entity) == .enemy) {
            var stun_turns = game.level.entities.item.get(item_id).throwStunTurns(&game.config);

            // Account for modifiers.
            if (game.level.entities.passive.get(id).stone_thrower) {
                stun_turns += 1;
            }

            if (hard) {
                stun_turns += 1;
            }

            if (stun_turns > 0) {
                // Stun the entity for a given number of turns.
                try game.log.log(.stun, .{ hit_entity, stun_turns });
            }

            // The entity perceives having been hit by something.
            const player_pos = game.level.entities.pos.get(hit_entity);
            const percept = game.level.entities.percept.get(hit_entity);
            game.level.entities.percept.getPtr(hit_entity).* = percept.perceive(Percept{ .hit = player_pos });
        }
    }

    // Move the item to its hit location.
    game.level.entities.pos.set(item_id, start);
    try game.log.log(.move, .{ item_id, .misc, .walk, hit_pos });

    // Remove the item from the inventory.
    game.level.entities.removeItem(id, item_id);
    game.level.entities.turn.getPtr(id).*.attack = true;

    // NOTE the radius here is the stone radius, regardless of item type
    try game.log.now(.sound, .{ id, hit_pos, game.config.sound_radius_stone });

    // Resolve specific items.
    if (game.level.entities.item.get(item_id) == .seedOfStone) {
        // Seed of stone creates a new wall, destroying anything in the hit tile.
        game.level.map.getPtr(hit_pos).center = Wall.tall();
        // This is playing a little fast and lose- we assume that if
        // the seed of stone hits a tile, that any entity at that tile
        // is something we can destroy like a sword or grass entity.
        // NOTE(perf) use frame allocator
        var entity_positions = ArrayList(Id).init(game.allocator);
        try game.level.entitiesAtPos(hit_pos, &entity_positions);
        for (entity_positions.items) |entity_id| {
            game.level.entities.markForRemoval(entity_id);
        }
        game.level.entities.markForRemoval(item_id);
    } else if (game.level.entities.item.get(item_id) == .seedCache) {
        // Seed cache creates a ground of grass tiles around the hit location.
        // NOTE(perf) use frame allocator.
        var floodfill = board.floodfill.FloodFill.init(game.allocator);
        try floodfill.fill(&game.level.map, hit_pos, game.config.seed_cache_radius);
        for (floodfill.flood.items) |seed_pos| {
            if (math.rand.rngTrial(game.rng.random(), 0.70)) {
                _ = try make_map.ensureGrass(game, seed_pos.pos);
            }
        }
        game.level.entities.markForRemoval(item_id);
    } else if (game.level.entities.item.get(item_id) == .smokeBomb) {
        // Smoke bomb creates a group of smoke tiles around the hit location.
        _ = try spawn.spawnSmoke(&game.level.entities, &game.config, hit_pos, game.config.smoke_bomb_fov_block, &game.log);
        var floodfill = board.floodfill.FloodFill.init(game.allocator);
        try floodfill.fill(&game.level.map, hit_pos, game.config.smoke_bomb_radius);
        for (floodfill.flood.items) |smoke_pos| {
            if (!smoke_pos.pos.eql(hit_pos)) {
                if (math.rand.rngTrial(game.rng.random(), 0.30)) {
                    _ = try spawn.spawnSmoke(&game.level.entities, &game.config, smoke_pos.pos, game.config.smoke_bomb_fov_block, &game.log);
                }
            }
        }
        game.level.entities.markForRemoval(item_id);
    } else if (game.level.entities.item.get(item_id) == .lookingGlass) {
        // NOTE(implement) this is part of magnification and not yet added back into the game.
        // The looking glass creates a magnifier in the hit location.
        //spawnMagnifier(&game.level.entities, &game.config, hit_pos, game.config.looking_glass_magnify_amount, game.log);
    } else if (game.level.entities.item.get(item_id) == .glassEye) {
        // NOTE(implement) consider moving this to the code for moving, or a special message for this item.
        // This would allow LoS calculations for the glass eye entity instead of the previous simple radius.

        // The glass eye creates entity impressions for entities that would otherwise
        // be out of field of view.
        //for pos in game.level.map.posInRadius(hit_pos, GLASS_EYE_RADIUS) {
        //    for eyed_id in game.level.getEntitiesAtPos(pos) {
        //        // Check if outside FoV. Inside entities are already visible,
        //        // and entities on the edge should already have impressions, so
        //        // we don't need to make one here.
        //        if (game.level.entities.typ.get(eyed_id) == .enemy &&
        //           game.level.isInFov(id, eyed_id) == .outside) {
        //            game.log.logInfo(.impression, pos);
        //        }
        //    }
        //}
    } else if (game.level.entities.item.get(item_id) == .teleporter) {
        // The teleporter moves the player to a random location around the hit location.
        const end_x = math.rand.rngRangeI32(game.rng.random(), hit_pos.x - 1, hit_pos.x + 1);
        const end_y = math.rand.rngRangeI32(game.rng.random(), hit_pos.y - 1, hit_pos.y + 1);
        var result_pos = Pos.init(end_x, end_y);
        if (!game.level.map.isWithinBounds(result_pos)) {
            result_pos = hit_pos;
        }
        try game.log.now(.move, .{ id, .blink, .walk, result_pos });
        game.level.entities.markForRemoval(item_id);
    }

    try game.log.log(.itemLanded, .{ item_id, start, hit_pos });
}

fn resolveInteract(game: *Game, id: Id, interact_pos: Pos) !void {
    const current_pos = game.level.entities.pos.get(id);

    if (current_pos.distanceMaximum(interact_pos) <= 1) {
        if (!current_pos.eql(interact_pos)) {
            const dir = Direction.fromPositions(current_pos, interact_pos).?;
            try game.log.now(.tryMove, .{ id, dir, 1 });
        }

        if (game.level.itemAtPos(interact_pos) != null) {
            try game.log.log(.pickup, id);
        }
    } else {
        //for (game.level.hasEntity(interact_pos)) |other_id| {
        //    if (level.entities.trap.get(&other_id) != null) {
        //        game.log.log(.armDisarmTrap, .{id, other_id});
        //        break;
        //    }
        //}
    }
}

fn resolveHammerRaise(game: *Game, id: Id, direction: Direction) !void {
    game.level.entities.status.getPtr(id).hammer_raised = direction;
    game.level.entities.turn.getPtr(id).*.pass = true;
}

fn resolveHammerSwing(game: *Game, id: Id, pos: Pos) !void {
    const entity_pos = game.level.entities.pos.get(id);

    try game.log.now(.blunt, .{ entity_pos, pos });

    const dir = Direction.fromPositions(entity_pos, pos).?;
    var hit_something: bool = false;
    if (blocking.moveBlocked(&game.level.map, entity_pos, dir, .move)) |blocked| {
        try game.log.now(.hammerHitWall, .{ id, blocked.start_pos, blocked.end_pos, blocked.direction });
        hit_something = true;
    } else if (game.level.blockingEntityAtPos(pos)) |hit_entity| {
        // we hit another entity!
        try game.log.now(.hammerHitEntity, .{ id, hit_entity });
        hit_something = true;
    }

    if (hit_something) {
        try game.log.log(.hit, .{ id, entity_pos, pos, .blunt, .strong });
    }

    game.level.entities.turn.getPtr(id).attack = true;
}

fn resolveHammerHitWall(game: *Game, id: Id, start_pos: Pos, end_pos: Pos, dir: Direction) !void {
    // If hit water, do nothing.
    if (game.level.map.get(end_pos).impassable) {
        return;
    }

    if (game.level.map.get(end_pos).center.height != .empty) {
        // Hammer hit a full tile wall.
        if (game.level.map.getPtr(end_pos).center.material == .stone) {
            game.level.map.getPtr(end_pos).center.material = .rubble;
        }
        game.level.map.getPtr(end_pos).center.height = .empty;

        const diff = end_pos.sub(start_pos);
        const next_pos = start_pos.nextPos(diff);
        try game.log.now(.crushed, .{ id, next_pos });
        try game.log.now(.sound, .{ id, end_pos, game.config.sound_radius_attack });
    } else {
        // hammer hit an inter-tile wall
        var wall_loc: Pos = undefined;
        var left_wall: bool = undefined;
        if (dir == .left) {
            wall_loc = start_pos;
            left_wall = true;
        } else if (dir == .right) {
            wall_loc = end_pos;
            left_wall = true;
        } else if (dir == .down) {
            wall_loc = start_pos;
            left_wall = false;
        } else if (dir == .up) {
            wall_loc = end_pos;
            left_wall = false;
        } else {
            std.debug.panic("Hammer direction was not up/down/left/right", .{});
        }

        if (left_wall) {
            game.level.map.getPtr(wall_loc).left.height = .empty;
        } else {
            game.level.map.getPtr(wall_loc).down.height = .empty;
        }

        try game.log.now(.crushed, .{ id, end_pos });
    }
}

fn resolveCrushed(game: *Game, id: Id, pos: Pos) !void {
    game.level.map.getPtr(pos).center.height = .empty;
    game.level.map.getPtr(pos).center.material = .rubble;

    // NOTE(perf) use frame allocator
    var hit_entities: ArrayList(Id) = ArrayList(Id).init(game.allocator);
    try game.level.entitiesAtPos(pos, &hit_entities);
    for (hit_entities.items) |crushed_id| {
        if (crushed_id == id) {
            continue;
        }

        if (game.level.entities.typ.get(crushed_id) == .column) {
            const entity_pos = game.level.entities.pos.get(id);
            const diff = entity_pos.sub(pos);
            const next_pos = entity_pos.nextPos(diff);

            try game.log.now(.crushed, .{ crushed_id, next_pos });
        }

        if (game.level.entities.hp.getOrNull(crushed_id)) |hp| {
            try game.log.log(.killed, .{ id, crushed_id, hp });
        } else if (game.level.entities.item.has(crushed_id) and
            game.level.entities.name.get(crushed_id) != .cursor)
        {
            // the entity will be removed, such as an item.
            game.level.entities.markForRemoval(crushed_id);
        }
    }

    try game.log.now(.sound, .{ id, pos, game.config.sound_radius_crushed });
}

fn resolveAiStep(game: *Game, id: Id) !void {
    try ai.stepAi(game, id);
}

fn resolveBehaviorChange(game: *Game, id: Id, behavior: Behavior) void {
    game.level.entities.behavior.getPtr(id).* = behavior;
}

fn resolveSound(game: *Game, id: Id, pos: Pos, amount: usize) !void {
    _ = id;
    var floodfill = try game.sound(pos, amount);
    defer floodfill.deinit();

    for (floodfill.flood.items) |hit_pos| {
        for (game.level.entities.ids.items) |entity_id| {
            if ((game.level.entities.status.get(entity_id).active) and
                (game.level.entities.pos.get(entity_id).eql(hit_pos.pos)) and
                (game.level.entities.typ.get(entity_id) == .enemy))
            {
                // Provide the perception of sound to the entity.
                const percept = game.level.entities.percept.get(entity_id);
                game.level.entities.percept.getPtr(entity_id).* = percept.perceive(Percept{ .sound = pos });
            }
        }
    }
}

fn resolveFaceTowards(game: *Game, id: Id, pos: Pos) !void {
    const entity_pos = game.level.entities.pos.get(id);
    if (Direction.fromPositions(entity_pos, pos)) |dir| {
        try resolveFacing(game, id, dir);
    }
}

fn resolveHit(game: *Game, id: Id, start_pos: Pos, hit_pos: Pos, weapon_type: WeaponType, attack_style: AttackStyle) !void {
    _ = start_pos;

    // Hitting always takes a turn currently.
    game.level.entities.turn.getPtr(id).attack = true;

    const entity_pos = game.level.entities.pos.get(id);

    if (game.level.firstEntityTypeAtPos(hit_pos, .enemy)) |hit_entity| {
        const percept = game.level.entities.percept.get(hit_entity);
        game.level.entities.percept.getPtr(hit_entity).* = percept.perceive(Percept{ .attacked = id });

        if (game.level.entities.typ.get(hit_entity) == .column) {
            // if we hit a column, and this is a strong, blunt hit, then
            // push the column over.
            if (weapon_type == .blunt and attack_style == .strong) {
                const dir = Direction.fromPositions(entity_pos, hit_pos).?;
                try game.log.log(.pushed, .{ id, hit_entity, dir, 1 });
            }
        } else {
            // if we hit an enemy, stun them and make a sound.
            if (game.level.entities.typ.get(hit_entity) == .enemy) {
                var hit_sound_radius: usize = 0;
                var stun_turns: usize = 0;
                switch (weapon_type) {
                    .pierce => {
                        hit_sound_radius = game.config.sound_radius_pierce;
                        stun_turns = game.config.stun_turns_pierce;
                    },

                    .slash => {
                        hit_sound_radius = game.config.sound_radius_slash;
                        stun_turns = game.config.stun_turns_slash;
                    },

                    .blunt => {
                        hit_sound_radius = game.config.sound_radius_blunt;
                        stun_turns = game.config.stun_turns_blunt;
                    },
                }

                // whet stone passive adds to sharp weapon stun turns
                if (game.level.entities.passive.get(id).whet_stone and weapon_type.sharp()) {
                    stun_turns += 1;
                }

                if (attack_style == .strong) {
                    hit_sound_radius += game.config.sound_radius_extra;
                    stun_turns += game.config.stun_turns_extra;
                }

                try game.log.log(.stun, .{ hit_entity, stun_turns });
                try game.log.log(.sound, .{ id, hit_pos, hit_sound_radius });
            }
        }
    }

    switch (weapon_type) {
        .blunt => {
            try game.log.log(.blunt, .{ entity_pos, hit_pos });
        },

        .pierce => {
            try game.log.log(.pierce, .{ entity_pos, hit_pos });
        },

        .slash => {
            try game.log.log(.slash, .{ entity_pos, hit_pos });
        },
    }
}

fn aiAttack(game: *Game, id: Id, target_id: Id) !void {
    const entity_pos = game.level.entities.pos.get(id);
    const target_pos = game.level.entities.pos.get(target_id);

    const attack_reach = game.level.entities.attack[id];
    const can_hit_target =
        ai.aiCanHitTarget(game, id, target_pos, attack_reach);

    if (game.level.entities.state(target_id) == .remove) {
        // If the target is no longer in play, return to idle.
        game.level.entities.turn.getPtr(id).pass = true;
        try game.log.log(.stateChange, .{ id, Behavior{.idle} });
    } else if (can_hit_target) {
        // If the entity can hit its target,
        var can_attack = true;
        // If the quick reflexes has quick reflexes they may dodge the attack.
        if (game.level.entities.passive.getOrNull(target_id)) |passives| {
            if (passives.quick_reflexes and
                math.rand.rngTrial(game.rng.random(), game.config.skill_quick_reflexes_percent))
            {
                can_attack = false;
                try game.log.log(.dodged, target_id);
            }
        }

        if (can_attack) {
            // NOTE Golem hits are piercing attacks even though they shoot a beam.
            try game.log.log(.hit, .{ id, entity_pos, target_pos, WeaponType.pierce, AttackStyle.normal });
        }
    } else if (game.level.isInFov(id, target_id) != .inside) {
        // If the target disappeared, change to idle- there is no need to
        // pursue their last position if we saw them blink away.
        if (game.level.entities.target_disappeared(id) != null) {
            try game.log.log(.stateChange, .{ id, .idle });
        } else {
            // If we lose the target, end the turn and investigate their current position.
            // This allows the golem to 'see' a player move behind a wall and still investigate
            // them instead of losing track of their position.
            game.level.entities.turn.getPtr(id).pass = true;
            const current_target_pos = game.level.entities.pos.get(target_id);
            try game.log.log(.stateChange, .{ id, Behavior{ .investigating = current_target_pos } });
        }
    } else {
        // Can see target, but can't hit them. try to move to a position where we can hit them
        const maybe_pos = ai.aiMoveToAttackPos(game, id, target_id);
        if (maybe_pos) |move_pos| {
            // Try to move in the given direction.
            const direction = Direction.fromPositions(entity_pos, move_pos).?;
            try game.log.log(.tryMove, .{ id, direction, 1, .walk });
        } else {
            // If we can't move anywhere, we just end our turn.
            game.level.entities.turn.getPtr(id).pass = true;
        }
    }
}

// TODO this needs to be merged with the concept of attacking, perhaps by merging into 'hit' message?
// Ideally this would be merged into the attack type concept, so a strong blunt attack always does the same
// thing whether its a hammer or not.
// Shield attacks would turn into push messages where the push logic would be in the message handler.
// Golem attacks might need their own attack type, like beam or energy.
//pub fn attack(entity: EntityId, target: EntityId, data: &mut Level, msg_log: &mut MsgLog) {
//    if data.using(entity, Item::Hammer).is_some() {
//        data.entities.status[&target].alive = false;
//        data.entities.blocks[&target] = false;
//
//        data.entities.take_damage(target, HAMMER_DAMAGE);
//        data.entities.messages[&target].push(Message::Attack(entity));
//
//        // NOTE assumes that this kills the enemy
//        msg_log.log(Msg::Killed(entity, target, HAMMER_DAMAGE));
//
//        let hit_pos = data.entities.pos[&target];
//        // NOTE this creates rubble even if the player somehow is hit by a hammer...
//        if data.map[hit_pos].surface == Surface::Floor {
//            data.map[hit_pos].surface = Surface::Rubble;
//        }
//    } else if data.using(target, Item::Shield).is_some() {
//        let pos = data.entities.pos[&entity];
//        let other_pos = data.entities.pos[&target];
//        let diff = sub_pos(other_pos, pos);
//
//        let x_diff = diff.x.signum();
//        let y_diff = diff.y.signum();
//
//        let past_pos = move_by(other_pos, Pos::new(x_diff, y_diff));
//
//        if !data.map.path_blocked_move(other_pos, Pos::new(x_diff, y_diff)).is_some() &&
//           !data.has_blocking_entity(past_pos).is_some() {
//            data.entities.set_pos(target, past_pos);
//            data.entities.set_pos(entity, other_pos);
//
//            data.entities.messages[&target].push(Message::Attack(entity));
//        }
//    } else if data.using(entity, Item::Sword).is_some() {
//        msg_log.log(Msg::Attack(entity, target, SWORD_DAMAGE));
//        msg_log.log(Msg::Killed(entity, target, SWORD_DAMAGE));
//    } else {
//        // NOTE could add another section for the sword- currently the same as normal attacks
//        let damage = 1;
//        if data.entities.take_damage(target, damage) {
//            msg_log.log(Msg::Attack(entity, target, damage));
//            // TODO consider moving this to the Attack msg
//            if data.entities.hp[&target].hp <= 0 {
//                msg_log.log(Msg::Killed(entity, target, damage));
//            }
//
//            data.entities.messages[&target].push(Message::Attack(entity));
//        }
//    }
//}
