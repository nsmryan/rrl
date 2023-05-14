const core = @import("core");
const Behavior = core.entities.Behavior;
const Entities = core.entities.Entities;

const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;

const Game = @import("game.zig").Game;

pub fn stepAi(game: *Game, id: Id) !void {
    switch (game.level.entities.behavior.get(id)) {
        .idle => {
            try stepAiIdle(game, id);
        },

        .alert => |pos| {
            _ = pos;
        },

        .investigating => |pos| {
            _ = pos;
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

    // NOTE(generality) this could use the view.pov.visible.iterator
    // and look for entities in FoV if golems need to see other entities
    // besides the player.
    const fov_result = try game.level.isInFov(id, player_pos, .high);

    if (fov_result == .inside) {
        try game.log.log(.faceTowards, .{ id, player_pos });

        // NOTE(design) should this be moved to Alert behavior? That way even armils would spend an alert turn.
        if (game.level.entities.attack.getOrNull(id) != null) {
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

                if (game.level.entities.attack.getOrNull(id) != null) {
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
