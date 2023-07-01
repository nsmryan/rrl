const std = @import("std");
const print = std.debug.print;
const BoundedArray = std.BoundedArray;

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

pub const ActionMode = enum {
    primary,
    alternate,
};

pub const UseDir = struct {
    move_pos: Pos,
    hit_positions: BoundedArray(Pos, 8),

    pub fn init() UseDir {
        var result = UseDir{
            .move_pos = Pos.init(-1, -1),
            .hit_positions = BoundedArray(Pos, 8).init(0) catch unreachable,
        };
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

pub fn startInteract(game: *Game) !void {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        var use_dir: UseDir = UseDir.init();

        const hit_pos = dir.offsetPos(player_pos, 1);
        use_dir.move_pos = player_pos;
        try use_dir.hit_positions.append(hit_pos);

        const dir_index = @enumToInt(dir);
        use_result.use_dir[dir_index] = use_dir;
    }

    game.settings.mode = Mode{ .use = .{
        .pos = null,
        .use_action = UseAction.interact,
        .dir = null,
        .use_result = use_result,
    } };

    game.changeState(.use);
}

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
            } else if (item == .khopesh) {
                use_result = try useKhopesh(game);
            } else if (item == .axe) {
                use_result = try useAxe(game);
            } else if (item == .hammer) {
                use_result = try useHammer(game);
            } else if (item == .sling) {
                use_result = try useSling(game);
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
    // TODO
    // add skills to player
    // index skills to check if slot is full.
    // if so, check skill mode- direction, immediate, cursor.
    // for immediate, Rust's handle_skill function switches on the skill enum
    // and processes the skill.
    // For direction skills, enter use mode with skill as the action.
    // For cursor skills, enter cursor mode with skill as the action.
    const player_id = Entities.player_id;

    if (game.level.find_skill(index)) |skill| {
        const use_action = UseAction::Skill(skill, action_mode);

        switch (skill.mode()) {
            .direction => {
                initializeUseMode(use_action, settings, msg_log);

                for (Direction::moveActions().iter()) |dir| {
                    const use_result = game.level.calculateUseSkill(player_id, skill, *dir, settings.move_mode);

                    if (use_result.pos) |hit_pos| {
                        try game.log.log_info(.useHitPos, hit_pos);
                        try game.log.log_info(.useOption, .{ hit_pos, *dir});
                    }

                    for (use_result.hit_positions.iter()) |hit_pos| {
                        try game.log.log_info(InfoMsg::UseHitPos(*hit_pos));
                    }
                }

                game.changeState(.use);

                try game.log.log(.startUseSkill, player_id);
            },

            .immediate => {
                // Handle the skill immediately, with no action location as the skill should not be
                // directional or based on a position.
                handleSkillIndex(game, index, ActionLoc::None, action_mode);
            },

            .cursor => {
                if (game.settings.cursor == null) {
                    const player_pos = game.level.entities.pos.get(player_id);
                    game.settings.cursor = player_pos;
                    try game.log.log(.cursorState, .{ true, player_pos } );
                }

                // Record skill as a use_action.
                game.settings.cursor_action = use_action;
                try game.log.log(cursorAction, use_action);
            },
        }
    }
}

pub fn startUseTalent(game: *Game, index: usize) !void {
    _ = index;
    // NOTE(implement) the player does not yet have talents, so there is no use in checking for one.
    // check if the indexed talent slot is full.
    // If so, immediately process the talent by emitting a log message to be processed.
    if (game.level.find_talent(index)) |talent| {
        switch (talent) {
            .invigorate => {
                try game.log.log(.refillStamina, Entities.player_id);
            },

            .strongAttack => {
                // TODO extra attack, perhaps as a status checked later?
            },

            .sprint => {
                // TODO extra sprint, perhaps as a status checked later?
            },

            .push => {
                // TODO push, but with some extra rules. Start with push message from use-mode
            },

            .energyShield => {
                // TODO add blue health concept. Likely a status effect used when reducing
                // hp, and get it into the display.
            },
        }
    }
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
            try use_dir.hit_positions.append(left_pos);

            const right_pos = dir.clockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.append(right_pos);

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
            try use_dir.hit_positions.append(hit_pos);

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
            try use_dir.hit_positions.append(hit_pos);

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
                try use_dir.hit_positions.append(far_target_pos);

                const close_target_pos = dir.offsetPos(player_pos, 3);
                try use_dir.hit_positions.append(close_target_pos);

                const dir_index = @enumToInt(dir);
                use_result.use_dir[dir_index] = use_dir;
            }
        } else {
            const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;
            if (is_clear_path) {
                var use_dir: UseDir = UseDir.init();

                use_dir.move_pos = player_pos;

                try use_dir.hit_positions.append(dir.offsetPos(player_pos, 2));

                try use_dir.hit_positions.append(dir.offsetPos(player_pos, 3));

                const dir_index = @enumToInt(dir);
                use_result.use_dir[dir_index] = use_dir;
            }
        }
    }

    return use_result;
}

pub fn useKhopesh(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        const target_pos = dir.offsetPos(player_pos, 1);
        const move_pos = dir.reverse().offsetPos(player_pos, 1);

        const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;
        if (is_clear_path) {
            var use_dir: UseDir = UseDir.init();

            use_dir.move_pos = move_pos;
            try use_dir.hit_positions.append(target_pos);

            const dir_index = @enumToInt(dir);
            use_result.use_dir[dir_index] = use_dir;
        }
    }

    return use_result;
}

pub fn useAxe(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        const target_pos = dir.offsetPos(player_pos, 1);

        const is_clear_path = blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null;
        if (is_clear_path) {
            var use_dir: UseDir = UseDir.init();

            use_dir.move_pos = player_pos;

            try use_dir.hit_positions.append(target_pos);

            const left_pos = dir.clockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.append(left_pos);

            const right_pos = dir.counterclockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.append(right_pos);

            const dir_index = @enumToInt(dir);
            use_result.use_dir[dir_index] = use_dir;
        }
    }

    return use_result;
}

pub fn useHammer(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        var use_dir: UseDir = UseDir.init();

        const hit_pos = dir.offsetPos(player_pos, 1);
        // Hammers can always be used in any direction.
        use_dir.move_pos = player_pos;
        try use_dir.hit_positions.append(hit_pos);

        const dir_index = @enumToInt(dir);
        use_result.use_dir[dir_index] = use_dir;
    }

    return use_result;
}

pub fn useSling(game: *Game) !UseResult {
    var use_result = UseResult.init();

    const player_pos = game.level.entities.pos.get(Entities.player_id);

    for (Direction.directions()) |dir| {
        var use_dir: UseDir = UseDir.init();

        const hit_pos = dir.offsetPos(player_pos, 1);
        use_dir.move_pos = player_pos;
        try use_dir.hit_positions.append(hit_pos);

        const dir_index = @enumToInt(dir);
        use_result.use_dir[dir_index] = use_dir;
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

        .interact => {
            try finalizeInteract(game);
        },
    }
}

pub fn finalizeInteract(game: *Game) !void {
    const dir = game.settings.mode.use.dir.?;
    const player_pos = game.level.entities.pos.get(Entities.player_id);
    const interact_pos = dir.offsetPos(player_pos, 1);
    try game.log.log(.interact, .{ Entities.player_id, interact_pos });
}

pub fn finalizeUseSkill(skill: Skill, action_mode: ActionMode, game: *Game) !void {
    const dir = settings.use_dir.expect("Finalizing use mode for an skill with no direction to take!");
    const use_result = level.calculate_use_skill(player_id, skill, dir, settings.move_mode);

    if (use_result.hit_positions.len() > 0) {
        const hit_pos = use_result.hit_positions[0];
        handleSkill(game, skill, ActionLoc.place(hit_pos), action_mode);
    }
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
            const stone_id = game.level.entities.inventory.get(player_id).throwing.?;
            try game.log.log(.itemThrow, .{ player_id, stone_id, player_pos, throw_pos, true });
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

pub fn handleSkill(game: *Game, skill: Skill, action_loc: ActionLoc, action_mode: ActionMode) !void {
    const player_id = Entities.player_id;
    const reach = Reach.single(1);

    // Determine Position Effected
    const skill_pos;
    switch (action_loc) {
        .dir => |dir| {
            const player_pos = game.level.entities.pos.get(player_id);
            if (reach.furthestInDirection(player_pos, dir)) |pos| {
                skill_pos = pos;
            } else {
                return;
            }
        },

        .place => |pos| {
            skill_pos = pos;
        },

        .facing => {
            const dir = game.level.entities.direction[&player_id];
            const player_pos = game.level.entities.pos.get(player_id);
            if (reach.furthestInDirection(player_pos, dir)) |pos| {
                skill_pos = pos;
            } else {
                return;
            }
        },

        .none => {
            //NOTE this used to return, but now uses current position.
            skill_pos = game.level.entities.pos.get(player_id);
        },
    }

    const player_pos = game.level.entities.pos.get(player_id);
    const dxy = skill_pos.sub(player_pos);
    const direction = Direction.fromPositiions(player_pos, skill_pos);

    // Carry Out Skill
    switch (skill) {
        .grassThrow => {
            if (direction) |dir| {
                try game.log.log(.grassThrow, .{ player_id, dir });
            }
        },

        .grassBlade => {
            if (direction) |dir| {
                try game.log.log(.grassBlade, .{ player_id, action_mode, dir });
            }
        },

        .blink => {
            try game.log.log(.blink, player_id);
        },

        .grassShoes => {
            try game.log.log(.grassShoes, .{ player_id, action_mode });
        },

        .grassWall => {
            // TODO should this stay here, or go to StartUseSkill?
            //settings.use_action = UseAction::Skill(skill, action_mode);
            //try game.log.log_info(InfoMsg::UseAction(settings.use_action));
            //settings.use_dir = None;
            //try game.log.log_info(InfoMsg::UseDirClear);
            //change_state(settings, GameState::Use, try game.log);
            // TODO remove when GrassWall is fully implemented with use-mode.
            // Unless skill use is left as-is in which case remove the code above.
            if (direction) |dir| {
                try game.log.log(.grassWall, .{ player_id, dir } );
            }
        },

        .grassCover => {
            try game.log.log(.grassCover, .{ player_id, action_mode });
        },

        .passWall => {
            if (direction) |dir| {
                const target_pos = dir.offsetPos(player_pos, 1);

                const maybe_blocked = game.level.map.pathBlockedMove(player_pos, target_pos);
                
                if (maybe_blocked) |blocked| {
                    if (game.level.map.tileIsBlocking(blocked.end_pos)) {
                        const next = nextFromTo(player_pos, blocked.end_pos);
                        if  (!game.level.map.tileIsBlocking(next)) {
                            try game.log.log(.passWall, .{ player_id, next } );
                        }
                    } else {
                        try game.log.log(.passWall, .{ player_id, skill_pos });
                    }
                }
            }
        },

        .rubble => {
            if (distance(player_pos, skill_pos) == 1) {
                try game.log.log(.rubble, .{ player_id, skill_pos });
            }
        },

        .reform => {
            if (distance(player_pos, skill_pos) == 1) {
                try game.log.log(.reform, .{ player_id, skill_pos } );
            }
        },

        .stoneThrow => {
            var near_rubble = game.level.map[player_pos].surface == Surface::Rubble;
            for (game.level.map.neighbors(player_pos)) |pos| {
                if (game.level.map[pos].surface == .rubble) {
                    near_rubble = true;
                }
                if near_rubble {
                    break;
                }
            }

            if (direction) |dir| {
                const target_pos = dir.offset_pos(player_pos, 1);

                try game.log.log(.stoneThrow, .{ player_id, target_pos });
            }
        },

        .stoneSkin => {
            try game.log.log(.stoneSkin, player_id);
        },

        .swap => {
            if (game.level.has_blocking_entity(skill_pos)) |entity_id| {
                try game.log.log(.swap, .{ player_id, entity_id });
            }
        },

        .push => {
            const push_amount = 1;
            if (direction) |dir| {
                try game.log.log(.push, .{ player_id, direction, push_amount });
            }
        },

        .traps => {
            if (direction) |dir| {
                try game.log.log(.interactTrap, .{ player_id, direction });
            }
        },

        .illuminate => {
            try game.log.log(.illuminate, .{ player_id, skill_pos, ILLUMINATE_AMOUNT });
        },

        .ping => {
            try game.log.log(.ping, .{ player_id, skill_pos });
        },

        .heal => {
            try game.log.log(.healSkill, .{ player_id, SKILL_HEAL_AMOUNT } );
        },

        .farSight => {
            try game.log.log(.tryFarSight, .{ player_id, SKILL_FARSIGHT_FOV_AMOUNT } );
        },

        .sprint => {
            if (direction) |dir| {
                try game.log.log(.sprint.{ player_id, dir, SKILL_SPRINT_AMOUNT ]);
            }
        },

        .roll => {
            if (direction) |dir| {
                try game.log.log(.roll.{ player_id, dir, SKILL_ROLL_AMOUNT });
            }
        },

        .passThrough => {
            if (direction) |dir| {
                try game.log.log(.tryPassThrough, .{ player_id, dir });
            }
        },

        .whirlWind => {
            if (game.level.map.is_within_bounds(skill_pos)) {
                try game.log.log(.whirlWind, .{ player_id, skill_pos });
            }
        },

        .swift => {
            if (direction) |dir| {
                try game.log.log(.trySwift, .{ player_id, dir });
            }
        },
    }
}

