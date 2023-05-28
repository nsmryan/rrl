const std = @import("std");
const print = std.debug.print;

const core = @import("core");
const Behavior = core.entities.Behavior;
const Entities = core.entities.Entities;
const Level = core.level.Level;
const astarPath = core.pathing.astarPath;

const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const Game = @import("game.zig").Game;

pub fn stepAi(game: *Game, id: Id) !void {
    switch (game.level.entities.behavior.get(id)) {
        .idle => {
            try stepAiIdle(game, id);
        },

        .alert => |pos| {
            try stepAiAlert(game, id, pos);
        },

        .investigating => |pos| {
            try stepAiInvestigate(game, id, pos);
        },

        .attacking => |target_id| {
            _ = target_id;
        },

        .armed => |countdown| {
            _ = countdown;
        },
    }
}

fn stepAiIdle(game: *Game, id: Id) !void {
    const player_id = Entities.player_id;
    const player_pos = game.level.entities.pos.get(player_id);
    const entity_pos = game.level.entities.pos.get(id);

    // NOTE(generality) this could use the view.pov.visible.iterator and look
    // for entities in FoV if golems need to see other entities besides the
    // player.
    const fov_result = try game.level.isInFov(id, player_pos, .high);

    if (fov_result == .inside) {
        try game.log.log(.faceTowards, .{ id, player_pos });

        // NOTE(design) should this be moved to Alert behavior? That way even armils would spend an alert turn.
        if (game.level.entities.attack.has(id)) {
            try game.log.log(.behaviorChange, .{ id, Behavior{ .alert = player_pos } });
            game.level.entities.turn.getPtr(id).pass = true;
        } else {
            try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = player_pos } });
        }
    } else {
        // Check entity perception for an event to react to.
        switch (game.level.entities.percept.get(id)) {
            .attacked => |attacker_id| {
                try game.log.log(.faceTowards, .{ id, entity_pos });

                if (game.level.entities.attack.has(id)) {
                    try game.log.log(.behaviorChange, .{ id, Behavior{ .attacking = attacker_id } });
                } else {
                    try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = entity_pos } });
                }

                // If attacked, react immediately instead of becoming alert for a turn.
                try game.log.log(.aiStep, id);
            },

            .hit => |origin_pos| {
                try game.log.log(.faceTowards, .{ id, origin_pos });
                try game.log.log(.behaviorChange, .{ id, Behavior{ .alert = origin_pos } });
                game.level.entities.turn.getPtr(id).pass = true;
            },

            .sound => |sound_pos| {
                if (try game.level.posInFov(id, sound_pos) == .inside) {
                    // Check if the sound was not just a golem in FoV then investigate.
                    if (game.level.firstEntityTypeAtPos(sound_pos, .enemy) != null) {
                        try game.log.log(.faceTowards, .{ id, sound_pos });
                        try game.log.log(.aiStep, id);
                    }
                } else {
                    if (game.level.entities.facing.get(id).isFacingPos(entity_pos, sound_pos)) {
                        // We are facing a sound we can't see- start investigating.
                        try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = sound_pos } });
                        try game.log.log(.aiStep, id);
                    } else {
                        // If we can't see the location of the sound and we aren't even facing it, face towards it
                        // and try again. If we still can't see it we will then enter the other brance of this 'if'.
                        try game.log.log(.faceTowards, .{ id, sound_pos });
                        try game.log.log(.aiStep, id);
                    }
                }
            },

            .none => {
                game.level.entities.turn.getPtr(id).pass = true;
            },
        }
    }
}

pub fn stepAiAlert(game: *Game, id: Id, pos: Pos) !void {
    const player_id = Entities.player_id;
    const player_pos = game.level.entities.pos.get(player_id);
    const can_see_target = try game.level.posInFov(id, player_pos) == .inside;

    if (can_see_target) {
        // Can see target- attack
        try game.log.log(.behaviorChange, .{ id, Behavior{ .attacking = player_id } });
        try game.log.log(.aiStep, id);
    } else {
        // NOTE(design) in the Rust version this used player_pos. This may have been to allow golems
        // to investigate the current player position even if they leave FoV?
        // Can't see target- investigate their last position.
        try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = pos } });
        try game.log.log(.aiStep, id);
    }
}

fn stepAiInvestigate(game: *Game, id: Id, target_pos: Pos) !void {
    const player_id = Entities.player_id;

    const entity_pos = game.level.entities.pos.get(id);

    const player_pos = game.level.entities.pos.get(player_id);
    const player_in_fov = try game.level.isInFov(id, player_pos, .high) == .inside;
    print("player_in_fov = {}\n", .{player_in_fov});

    if (player_in_fov) {
        try game.log.log(.faceTowards, .{ id, player_pos });

        if (game.level.entities.attack.has(id)) {
            try game.log.log(.behaviorChange, .{ id, Behavior{ .attacking = player_id } });
        } else {
            // NOTE(design) is this even used? what golem can see the player but not attack?
            // if the golem cannot attack, just keep walking towards the target.
            try aiMoveTowardsTarget(game, player_pos, id);

            game.level.entities.turn.getPtr(id).pass = true;
            try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = player_pos } });
        }
    } else {
        // Golem cannot see the player- investigate the given position 'target_pos'.

        // Handle Armils separately. They can never see the player so we always get here.
        if (game.level.entities.name.get(id) == .armil) {
            // If next to the player, arm to explode.
            if (player_pos.distance(entity_pos) == 1) {
                game.level.entities.turn.getPtr(id).pass = true;
                try game.log.log(.behaviorChange, .{ id, Behavior{ .armed = game.config.armil_turns_armed } });
            } else {
                // Otherwise move to the player.j
                try aiMoveTowardsTarget(game, player_pos, id);
            }
        } else {
            // Other golems react to perceptions.
            // If no perceptions this turn, just walk towards target.
            // NOTE(design) if hit or attacked, do we take 1 or 2 turns to react?
            switch (game.level.entities.percept.get(id)) {
                .attacked => {
                    // Just face towards the attacker. We can act on this on the next turn.
                    try game.log.log(.faceTowards, .{ id, entity_pos });

                    // NOTE Removed so we only face towards the attacker.
                    //if game.level.entities.attack.get(&monster_id).is_some() {
                    //    msg_log.log(Msg::StateChange(monster_id, Behavior::Attacking(entity_id)));
                    //} else {
                    //    msg_log.log(Msg::StateChange(monster_id, Behavior::Investigating(entity_pos)));
                    //}
                },

                .hit => |origin_pos| {
                    try game.log.log(.faceTowards, .{ id, origin_pos });
                    try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = origin_pos } });
                },

                .sound => |sound_pos| {
                    const can_see = try game.level.posInFov(id, sound_pos) == .inside;

                    const caused_by_golem = game.level.firstEntityTypeAtPos(sound_pos, .enemy) != null;
                    const needs_investigation = !(can_see and caused_by_golem);

                    // Only investigate if: we can't see the tile, or we can see it and there is not
                    // already a golem there.
                    // This prevents golems from following each other around when they should realize
                    // that a sound is caued by another golem
                    if (needs_investigation) {
                        try game.log.log(.faceTowards, .{ id, sound_pos });
                        try game.log.log(.behaviorChange, .{ id, Behavior{ .investigating = sound_pos } });
                    }
                },

                .none => {
                    // If the golem reached the target, they become idle.
                    // If they are next to the target, and it is occupied, they also become idle,
                    // but face towards the target in case they aren't already.
                    // Otherwise they attempt to step towards the target position.
                    const nearly_reached_target = target_pos.distance(entity_pos) == 1 and game.level.posBlockedMove(target_pos);
                    const reached_target = target_pos.eql(entity_pos);
                    if (reached_target or nearly_reached_target) {
                        if (nearly_reached_target) {
                            try game.log.log(.faceTowards, .{ id, target_pos });
                        }

                        // Golem reached their target position
                        game.level.entities.turn.getPtr(id).pass = true;
                        try game.log.log(.behaviorChange, .{ id, Behavior.idle });
                    } else {
                        try aiMoveTowardsTarget(game, target_pos, id);
                    }
                },
            }
        }
    }
}

fn aiMoveCostFunction(level: *const Level, current_pos: Pos, start_pos: Pos) ?i32 {
    _ = start_pos;

    // If the tile has an item, which is a trap, which is armed, then return null to indicate
    // that this move is not allowed.
    if (level.itemAtPos(current_pos)) |item_id| {
        if (level.entities.trap.has(item_id) and level.entities.armed.get(item_id)) {
            return null;
        }
    }
    return 0;
}

fn aiMoveTowardsTarget(game: *Game, target_pos: Pos, id: Id) !void {
    const entity_pos = game.level.entities.pos.get(id);
    const reach = game.level.entities.movement.get(id);

    // NOTE(perf) make sure to use frame allocator here.
    const next_positions = try astarPath(&game.level, entity_pos, target_pos, reach, aiMoveCostFunction, game.allocator);
    defer next_positions.deinit();

    if (next_positions.items.len > 1) {
        const move_pos = next_positions.items[1];
        const dir = Direction.fromPositions(entity_pos, move_pos).?;
        try game.log.log(.tryMove, .{ id, dir, 1 });
        try game.log.log(.faceTowards, .{ id, target_pos });
    }
}
