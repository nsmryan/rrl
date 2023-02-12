const std = @import("std");
const print = std.debug.print;

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const InventorySlot = core.items.InventorySlot;
const Entities = core.entities.Entities;
const MoveMode = core.movement.MoveMode;

const gen = @import("gen");
const MapGenType = gen.make_map.MapGenType;
const MapLoadConfig = gen.make_map.MapLoadConfig;

const input = @import("input.zig");
const MouseClick = input.MouseClick;
const KeyDir = input.KeyDir;

const s = @import("settings.zig");
const GameState = s.GameState;
const Mode = s.Mode;

const g = @import("game.zig");
const Game = g.Game;

pub const ActionMode = enum {
    primary,
    alternate,
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

        // drop item
        // use dir
        // finalize use
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
            game.settings.mode = Mode{ .use = .{ .pos = null, .use_action = UseAction{ .item = slot }, .dir = null } };

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
