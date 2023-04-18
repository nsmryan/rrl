const std = @import("std");
const print = std.debug.print;

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const InventorySlot = core.items.InventorySlot;
const AttackStyle = core.items.AttackStyle;
const Entities = core.entities.Entities;
const MoveMode = core.movement.MoveMode;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

const input = @import("input.zig");
const MouseClick = input.MouseClick;
const KeyDir = input.KeyDir;

const board = @import("board");
const blocking = board.blocking;

const s = @import("settings.zig");
const GameState = s.GameState;
const Mode = s.Mode;

const g = @import("game.zig");
const Game = g.Game;

const Array = @import("utils").buffer.Array;

pub const ActionMode = enum {
    primary,
    alternate,
};

pub const UseDir = struct {
    move_pos: Pos,
    hit_positions: Array(Pos, 8),

    pub fn init() UseDir {
        var result = UseDir{ .move_pos = Pos.init(-1, -1), .hit_positions = Array(Pos, 8).init() };
        return result;
    }
};

pub const UseResult = struct {
    use_dir: [8]?UseDir,

    pub fn init() UseResult {
        return UseResult{ .use_dir = [1]?UseDir{null} ** 8 };
    }

    pub fn clear(use_result: *UseResult) void {
        for (use_result.mem[0..]) |*dir| {
            dir.* = UseDir.init();
        }
    }

    pub fn inDirection(use_result: *const UseResult, dir: Direction) ?UseDir {
        return use_result.use_dir[@enumToInt(dir)];
    }
};

pub const UseAction = union(enum) {
    item: InventorySlot,
    skill: struct { skill: Skill, action_mode: ActionMode },
    talent: Talent,
    interact,
};

pub fn startUseItem(game: *Game, slot: InventorySlot) !void {
    // Check that there is an item in the requested slot. If not, ignore the action.
    if (game.level.entities.inventory.get(Entities.player_id).accessSlot(slot)) |item_id| {
        // There is an item in the slot. Handle instant items immediately, enter cursor
        // mode for stones with the action set to a UseAction.item, and for other items enter use-mode.
        const item = game.level.entities.item.get(item_id);
        if (item == .herb) {
            try game.log.log(.eatHerb, .{ Entities.player_id, item_id });
        } else if (item.isThrowable()) {
            var cursor_pos = game.level.entities.pos.get(Entities.player_id);
            if (game.settings.mode != .cursor) {
                // Enter cursor mode. This will use the player position here and below.
                try game.log.log(.cursorStart, cursor_pos);
            } else {
                // Otherwise keep the current cursor position.
                cursor_pos = game.settings.mode.cursor.pos;
            }
            game.settings.mode = Mode{ .cursor = .{ .pos = cursor_pos, .use_action = UseAction{ .item = slot } } };
        } else {
            var use_result: UseResult = undefined;
            if (item == .sword) {
                use_result = try useSword(game);
            } else if (item == .dagger) {
                use_result = try useDagger(game);
            } else if (item == .shield) {
                use_result = try useShield(game);
            } else if (item == .spear) {
                use_result = try useSpear(game);
            } else {
                @panic("Item not yet implemented for use-mode!");
            }
            game.settings.mode = Mode{ .use = .{
                .pos = null,
                .use_action = UseAction{ .item = slot },
                .dir = null,
                .use_result = use_result,
            } };

            game.changeState(.use);

            try game.log.log(.startUseItem, slot);
        }
    }
}

pub fn startUseSkill(game: *Game, index: usize, action: ActionMode) !void {
    _ = game;
    _ = index;
    _ = action;
    // TODO
    // add skills to player
    // index skills to check if slot is full.
    // if so, check skill mode- direction, immediate, cursor.
    // for immediate, Rust's handle_skill function switches on the skill enum
    // and processes the skill.
    // For direction skills, enter use mode with skill as the action.
    // For cursor skills, enter cursor mode with skill as the action.
}

pub fn startUseTalent(game: *Game, index: usize) !void {
    _ = game;
    _ = index;
    // NOTE(implement) the player does not yet have talents, so there is no use in checking for one.
    // check if the indexed talent slot is full.
    // If so, immediately process the talent by emitting a log message to be processed.
}

// NOTE
// implementing use-mode: add a UseDir struct with Array(8, ?UseResult)
// UseResult then has a move_pos: Pos and Array(8, Pos) hit_positions.
// calculate this immediately on enter use mode, and make part of its mode structure.
// keep track of ?Dir separately as selection within these options.
// likely add some convenience to mode concept.
//
pub fn useDir(dir: Direction, game: *Game) void {
    game.settings.mode.use.dir = dir;
}

pub fn useSword(game: *Game) !UseResult {
    const player_pos = game.level.entities.pos.get(Entities.player_id);

    var use_result = UseResult.init();

    for (Direction.directions()) |dir| {
        const target_pos = dir.offsetPos(player_pos, 1);

        // If move is not blocked, determine the outcome of the move.
        if (board.blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null) {
            var use_dir: UseDir = UseDir.init();
            use_dir.move_pos = target_pos;

            const left_pos = dir.counterclockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.push(left_pos);

            const right_pos = dir.clockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.push(right_pos);

            const dir_index = @enumToInt(dir);
            use_result.use_dir[dir_index] = use_dir;
        }
    }

    return use_result;
}

pub fn useDagger(game: *Game) !UseResult {
    const player_pos = game.level.entities.pos.get(Entities.player_id);

    var use_result = UseResult.init();

    for (Direction.directions()) |dir| {
        const target_pos = dir.offsetPos(player_pos, 1);
        const hit_pos = dir.offsetPos(target_pos, 1);

        const is_crouching = game.level.entities.stance.get(Entities.player_id) == .crouching;
        const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;

        // If crouching and not blocked, then the dagger can be used.
        if (is_crouching and is_clear_path) {
            var use_dir: UseDir = UseDir.init();
            use_dir.move_pos = target_pos;
            try use_dir.hit_positions.push(hit_pos);

            const dir_index = @enumToInt(dir);
            use_result.use_dir[dir_index] = use_dir;
        }
    }

    return use_result;
}

pub fn useShield(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);
    const facing = game.level.entities.facing.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        const target_pos = dir.offsetPos(player_pos, 1);
        const hit_pos = dir.offsetPos(target_pos, 1);

        const in_facing_dir = dir == facing;
        const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;

        // Shield attacks only occur in the entities' facing direction,
        // and if there is a path to the hit position.
        if (in_facing_dir and is_clear_path) {
            var use_dir: UseDir = UseDir.init();
            use_dir.move_pos = target_pos;
            try use_dir.hit_positions.push(hit_pos);

            const dir_index = @enumToInt(dir);
            use_result.use_dir[dir_index] = use_dir;
        }
    }

    return use_result;
}

pub fn useSpear(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);
    const move_mode = game.level.entities.move_mode.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        // If running, we can also attack an extra tile and move towards the golem.
        if (move_mode == .run) {
            // Move pos is where the entity will run to.
            const move_pos = dir.offsetPos(player_pos, 2);

            // Intermediate position between current and move pos.
            const next_pos = dir.offsetPos(player_pos, 1);

            // We can only spear if there is a clear path to the player's position.
            const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;
            const is_clear_path_next = blocking.moveBlocked(&game.level.map, next_pos, dir, .move) == null;
            if (is_clear_path and is_clear_path_next) {
                var use_dir: UseDir = UseDir.init();
                use_dir.move_pos = move_pos;

                // the spear will hit both intervening positions.
                const far_target_pos = dir.offsetPos(player_pos, 4);
                try use_dir.hit_positions.push(far_target_pos);

                const close_target_pos = dir.offsetPos(player_pos, 3);
                try use_dir.hit_positions.push(close_target_pos);

                const dir_index = @enumToInt(dir);
                use_result.use_dir[dir_index] = use_dir;
            }
        } else {
            const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;
            if (is_clear_path) {
                var use_dir: UseDir = UseDir.init();

                use_dir.move_pos = player_pos;

                try use_dir.hit_positions.push(dir.offsetPos(player_pos, 2));

                try use_dir.hit_positions.push(dir.offsetPos(player_pos, 3));

                const dir_index = @enumToInt(dir);
                use_result.use_dir[dir_index] = use_dir;
            }
        }
    }

    return use_result;
}

pub fn finalizeUse(game: *Game) !void {
    // If there is no direction, the user tried an invalid movement.
    // Returning here will just end use-mode.
    if (game.settings.mode.use.dir == null) {
        return;
    }

    switch (game.settings.mode.use.use_action) {
        .item => |slot| {
            try finalizeUseItem(slot, game);
        },

        .skill => |params| {
            try finalizeUseSkill(params.skill, params.action_mode, game);
        },

        .talent => |talent| {
            _ = talent;
        },

        .interact => {},
    }
}

pub fn finalizeUseSkill(skill: Skill, action_mode: ActionMode, game: *Game) !void {
    _ = skill;
    _ = action_mode;
    _ = game;
}

pub fn finalizeUseItem(slot: InventorySlot, game: *Game) !void {
    const player_id = Entities.player_id;
    const player_pos = game.level.entities.pos.get(player_id);

    const mode = game.settings.mode;

    if (game.level.entities.inventory.get(player_id).accessSlot(slot)) |item_id| {
        const item = game.level.entities.item.get(item_id);

        // There should be no way to get here without a direction
        const dir = mode.use.dir.?;
        if (mode.use.use_result.?.use_dir[@enumToInt(dir)] == null) {
            return;
        }

        // Determine action to take based on weapon type.
        if (item == .hammer) {
            if (game.level.entities.hasEnoughEnergy(player_id, 1)) {
                // Stamina is used on hammer strike
                try game.log.log(.hammerRaise, .{ player_id, dir });
            } else {
                try game.log.log(.notEnoughEnergy, player_id);
            }
        } else if (item == .spikeTrap or item == .soundTrap or item == .blinkTrap or item == .freezeTrap) {
            const place_pos = dir.offsetPos(player_pos, 1);
            try game.log.log(.placeTrap, .{ player_id, place_pos, item_id });
        } else if (item.isThrowable()) {
            const throw_pos = dir.offsetPos(player_pos, @intCast(i32, game.config.player_throw_dist));
            try game.log.log(.itemThrow, .{ player_id, item_id, player_pos, throw_pos, false });
        } else if (item == .sling) {
            const throw_pos = dir.offsetPos(player_pos, @intCast(i32, game.config.player_sling_dist));
            try game.log.log(.itemThrow, .{ player_id, item_id, player_pos, throw_pos, true });
        } else {
            // It is possible to select a direction, then press shift, causing the move to be
            // invalid. In this case we just suppress the action, and return to playing.
            // Otherwise, process the move below.
            if (mode.use.use_result.?.use_dir[@enumToInt(dir)]) |*use_dir| {
                if (game.level.entities.hasEnoughEnergy(player_id, 1)) {
                    if (!use_dir.move_pos.eql(player_pos)) {
                        const move_dir = Direction.fromPositions(player_pos, use_dir.move_pos).?;
                        const dist = @intCast(usize, use_dir.move_pos.distanceMaximum(player_pos));
                        try game.log.log(.tryMove, .{ player_id, move_dir, dist });
                    }

                    var attack_type: AttackStyle = .normal;
                    if (item == .spear and game.level.entities.next_move_mode.get(player_id) == .run) {
                        attack_type = .strong;
                    } else if (item == .dagger) {
                        attack_type = .stealth;
                    }

                    for (use_dir.hit_positions.constSlice()) |hit_pos| {
                        const weapon_type = item.weaponType().?;
                        try game.log.log(.hit, .{ player_id, player_pos, hit_pos, weapon_type, attack_type });
                    }
                } else {
                    try game.log.log(.notEnoughEnergy, player_id);
                }
            }
        }
    }
}
