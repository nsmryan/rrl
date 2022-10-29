const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const ItemClass = core.items.ItemClass;

const input = @import("input.zig");
const MouseClick = input.MouseClick;
const KeyDir = input.KeyDir;

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
