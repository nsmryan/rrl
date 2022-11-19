const std = @import("std");

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const ItemClass = core.items.ItemClass;
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

const g = @import("game.zig");
const Game = g.Game;

pub const ActionMode = enum {
    primary,
    alternate,
};

pub const UseAction = union(enum) {
    item: ItemClass,
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
    startUseItem: ItemClass,
    startUseSkill: struct { index: usize, action: ActionMode },
    startUseTalent: usize,
    useDir: Direction,
    finalizeUse,
    abortUse,
    pass,
    throwItem: struct { pos: Pos, item_class: ItemClass },
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
        .playing => {
            switch (input_action) {
                .move => |dir| try game.log.log(.tryMove, .{ Entities.player_id, dir, game.level.entities.next_move_mode.get(Entities.player_id).moveAmount() }),

                .run => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.run }),

                .sneak => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.sneak }),

                .walk => try game.log.log(.nextMoveMode, .{ Entities.player_id, MoveMode.walk }),

                .pass => try game.log.log(.pass, Entities.player_id),

                // TODO for now esc exits, but when menus work only exit should exit the game.
                .esc => game.changeState(.exit),
                else => {},
            }
        },
        .win => {},
        .lose => {},
        .inventory => {},
        .skillMenu => {},
        .classMenu => {},
        .helpMenu => {},
        .confirmQuit => {},
        .use => {},
        .exit => {},
    }
}
