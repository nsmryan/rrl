const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;

pub const Behavior = union(enum) {
    idle,
    alert: Pos,
    investigating: Pos,
    attacking: Id,
    armed: usize, // countdown

    pub fn isAware(behavior: Behavior) bool {
        return behavior == .attacking;
    }
};
