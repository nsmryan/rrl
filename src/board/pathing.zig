const utils = @import("utils");
const Pos = utils.pos.Pos;
const Line = utils.line.Line;

const blocking = @import("blocking.zig");
const Blocked = blocking.Blocked;
const BlockedType = blocking.BlockedType;

const Map = @import("map.zig").Map;

pub fn pathBlockedFov(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.fov);
}

pub fn pathBlockedFovLow(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.fovLow);
}

pub fn pathBlockedMove(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.move);
}

pub fn pathBlocked(map: Map, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) ?Blocked {
    var line = Line.init(start_pos, end_pos, false);

    var last_pos = start_pos;
    while (line.next()) |target_pos| {
        const blocked = blocking.moveBlocked(map, last_pos, target_pos, blocked_type);
        if (blocked != null) {
            return blocked;
        }
        last_pos = target_pos;
    }

    return null;
}
