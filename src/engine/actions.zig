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

const use = @import("use.zig");

const Array = @import("utils").buffer.Array;

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
        action: use.ActionMode,
    },
    skillFacing: struct {
        index: usize,
        action: use.ActionMode,
    },
    startUseItem: InventorySlot,
    startUseSkill: struct { index: usize, action: use.ActionMode },
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
            try use.startUseItem(game, slot);
        },

        .startUseSkill => |args| {
            try use.startUseSkill(game, args.index, args.action);
        },

        .startUseTalent => |index| {
            try use.startUseTalent(game, index);
        },

        .yell => try game.log.log(.yell, Entities.player_id),

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
            try use.startUseItem(game, slot);
        },

        .startUseSkill => |args| {
            try use.startUseSkill(game, args.index, args.action);
        },

        .startUseTalent => |index| {
            try use.startUseTalent(game, index);
        },

        .dropItem => {
            const slot = game.settings.mode.use.use_action.item;
            const item_id = game.level.entities.inventory.get(Entities.player_id).accessSlot(slot).?;
            try game.log.log(.dropItem, .{ Entities.player_id, item_id });
            game.settings.mode = .playing;
            game.changeState(.playing);
        },

        .useDir => |dir| {
            use.useDir(dir, game);
        },

        .finalizeUse => {
            try use.finalizeUse(game);
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
        if (game.settings.mode.cursor.use_action) |use_action| {
            switch (use_action) {
                .item => |slot| {
                    const inventory = game.level.entities.inventory.get(Entities.player_id);
                    if (inventory.accessSlot(slot)) |item_id| {
                        const player_pos = game.level.entities.pos.get(Entities.player_id);
                        const throw_pos = game.settings.mode.cursor.pos;

                        // Throwing to the current tile does nothing.
                        if (!player_pos.eql(throw_pos)) {
                            try game.log.log(.itemThrow, .{ Entities.player_id, item_id, player_pos, throw_pos, false });
                        }
                    } else {
                        @panic("Throwing an item, but no item available of that type!");
                    }
                },

                // NOTE(implement) skill as well.
                else => {},
            }
        }

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
