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

pub const InputAction = union(enum) {
    run,
    sneak,
    walk,
    alt,
    move: Direction,
    moveTowardsCursor,
    skillPos: struct {
        index: usize,
        pos: Pos,
        action: ActionMode,
    },
    skillFacing: struct {
        index: usize,
        action: ActionMode,
    },
    startUseItem: InventorySlot,
    startUseSkill: struct { index: usize, action: ActionMode },
    startUseTalent: usize,
    useDir: Direction,
    finalizeUse,
    abortUse,
    pass,
    throwItem: struct { pos: Pos, slot: InventorySlot },
    pickup,
    dropItem,
    yell,
    cursorMove: struct { dir: Direction, is_relative: bool, is_long: bool },
    cursorReturn,
    cursorToggle,
    mousePos: Pos,
    mouseButton: struct { mouse_click: MouseClick, key_dir: KeyDir },
    inventory,
    skillMenu,
    classMenu,
    helpMenu,
    exit,
    esc,
    forceExit,
    exploreAll,
    regenerateMap,
    testMode,
    overlayToggle,
    selectEntry: usize,
    debugToggle,
    restart,
    none,
};

pub fn resolveAction(game: *Game, input_action: InputAction) !void {
    switch (game.settings.state) {
        .playing => try resolveActionPlaying(game, input_action),
        .win => {},
        .lose => {},
        .inventory => {},
        .skillMenu => {},
        .classMenu => {},
        .helpMenu => {},
        .confirmQuit => {},
        .splash => try resolveActionSplash(game, input_action),
        .use => try resolveActionUse(game, input_action),
        .exit => {},
    }
}

pub fn resolveActionPlaying(game: *Game, input_action: InputAction) !void {
    switch (input_action) {
        .move => |dir| try game.log.log(.tryMove, .{ Entities.player_id, dir, game.level.entities.next_move_mode.get(Entities.player_id).moveAmount() }),

        .run => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.run }),

        .sneak => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.sneak }),

        .walk => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.walk }),

        .pass => try game.log.log(.pass, Entities.player_id),

        .cursorToggle => try cursorToggle(game),

        .cursorMove => |args| try cursorMove(game, args.dir, args.is_relative, args.is_long),

        .cursorReturn => cursorReturn(game),

        .pickup => try game.log.log(.pickup, Entities.player_id),

        .startUseItem => |slot| {
            try startUseItem(game, slot);
        },

        .startUseSkill => |args| {
            try startUseSkill(game, args.index, args.action);
        },

        .startUseTalent => |index| {
            try startUseTalent(game, index);
        },

        // TODO for now esc exits, but when menus work only exit should exit the game.
        .esc => game.changeState(.exit),
        else => {},
    }
}

pub fn resolveActionUse(game: *Game, input_action: InputAction) !void {
    switch (input_action) {
        .run => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.run }),

        .sneak => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.sneak }),

        .walk => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.walk }),

        .startUseItem => |slot| {
            try startUseItem(game, slot);
        },

        .startUseSkill => |args| {
            try startUseSkill(game, args.index, args.action);
        },

        .startUseTalent => |index| {
            try startUseTalent(game, index);
        },

        .dropItem => {
            const slot = game.settings.mode.use.use_action.item;
            const item_id = game.level.entities.inventory.get(Entities.player_id).accessSlot(slot).?;
            try game.log.log(.dropItem, .{ Entities.player_id, item_id });
            game.settings.mode = .playing;
            game.changeState(.playing);
        },

        .useDir => |dir| {
            useDir(dir, game);
        },

        .finalizeUse => {
            try finalizeUse(game);
            game.changeState(.playing);
        },

        // abort use mode
        // overlay toggle
        // TODO for now esc exits, but when menus work only exit should exit the game.
        .esc => game.changeState(.exit),
        else => {},
    }
}

pub fn resolveActionSplash(game: *Game, input_action: InputAction) !void {
    switch (input_action) {
        .esc => game.changeState(.exit),
        else => game.changeState(.playing),
    }
}

fn cursorToggle(game: *Game) !void {
    if (game.settings.mode == .cursor) {
        game.settings.mode = .playing;
        try game.log.log(.cursorEnd, .{});
    } else {
        const player_pos = game.level.entities.pos.get(Entities.player_id);
        game.settings.mode = s.Mode{ .cursor = .{ .pos = player_pos, .use_action = null } };
        try game.log.log(.cursorStart, player_pos);
    }
}

fn cursorMove(game: *Game, dir: Direction, is_relative: bool, is_long: bool) !void {
    std.debug.assert(game.settings.mode == .cursor);
    const player_pos = game.level.entities.pos.get(Entities.player_id);
    const cursor_pos = game.settings.mode.cursor.pos;

    var dist: i32 = 1;
    if (is_long) {
        dist = game.config.cursor_fast_move_dist;
    }

    const dir_move: Pos = dir.intoMove().scale(dist);

    var new_pos: Pos = undefined;
    if (is_relative) {
        new_pos = player_pos.add(dir_move);
    } else {
        new_pos = cursor_pos.add(dir_move);
    }

    new_pos = game.level.map.dims().clamp(new_pos);

    try game.log.log(.cursorMove, new_pos);
    game.settings.mode.cursor.pos = new_pos;
}

fn cursorReturn(game: *Game) void {
    std.debug.assert(game.settings.mode == .cursor);
    game.settings.mode.cursor.pos = game.level.entities.pos.get(Entities.player_id);
}

fn startUseItem(game: *Game, slot: InventorySlot) !void {
    // Check that there is an item in the requested slot. If not, ignore the action.
    if (game.level.entities.inventory.get(Entities.player_id).accessSlot(slot)) |item_id| {
        // There is an item in the slot. Handle instant items immediately, enter cursor
        // mode for stones with the action set to a UseAction.item, and for other items enter use-mode.
        const item = game.level.entities.item.get(item_id);
        if (item == .herb) {
            try game.log.log(.eatHerb, .{ Entities.player_id, item_id });
        } else if (item == .stone) {
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
            const use_result = try useSword(game);
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

fn startUseSkill(game: *Game, index: usize, action: ActionMode) !void {
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

fn startUseTalent(game: *Game, index: usize) !void {
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
fn useDir(dir: Direction, game: *Game) void {
    game.settings.mode.use.dir = dir;
}

fn useSword(game: *Game) !UseResult {
    const player_pos = game.level.entities.pos.get(Entities.player_id);

    var use_result = UseResult.init();

    for (Direction.directions()) |dir| {
        var use_dir = UseDir.init();

        const dir_index = @enumToInt(dir);
        const target_pos = dir.offsetPos(player_pos, 1);

        // If move is not blocked, determine the outcome of the move.
        if (board.blocking.moveBlocked(&game.level.map, player_pos, dir, .move) == null) {
            use_dir.move_pos = target_pos;

            const left_pos = dir.counterclockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.push(left_pos);

            const right_pos = dir.clockwise().offsetPos(player_pos, 1);
            try use_dir.hit_positions.push(right_pos);
        }
        use_result.use_dir[dir_index] = use_dir;
    }

    return use_result;
}

fn finalizeUse(game: *Game) !void {
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

        // determine action to take based on weapon type
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
                        try game.log.log(.hit, .{ player_id, hit_pos, weapon_type, attack_type });
                    }
                } else {
                    try game.log.log(.notEnoughEnergy, player_id);
                }
            }
        }
    }
}
