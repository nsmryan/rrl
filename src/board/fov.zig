const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DynamicBitSet = std.DynamicBitSet;

const math = @import("math");
const pos = math.pos;
const Pos = pos.Pos;
const Direction = math.direction.Direction;
const Dims = math.utils.Dims;

const blocking = @import("blocking.zig");
const FovResult = blocking.FovResult;
const Blocked = blocking.Blocked;

const pathing = @import("pathing.zig");

const Map = @import("map.zig").Map;
const Height = @import("tile.zig").Tile.Height;

const shadowcasting = @import("shadowcasting.zig");
const Pov = shadowcasting.Pov;

pub const FovError = error{OutOfMemory} || shadowcasting.Error;

pub const FovBlock = union(enum) {
    block,
    transparent,
    opaqu: usize,
    magnify: usize,
};

pub const ViewHeight = enum {
    low,
    high,
};

pub const View = struct {
    map: Pov,
    low: Pov,
    high: Pov,
    explored: DynamicBitSet,

    pub fn init(dims: Dims, allocator: Allocator) !View {
        const numTiles = dims.numTiles();
        return View{
            .map = try Pov.init(dims, allocator),
            .low = try Pov.init(dims, allocator),
            .high = try Pov.init(dims, allocator),
            .explored = try DynamicBitSet.initEmpty(allocator, numTiles),
        };
    }

    pub fn deinit(view: *View) void {
        view.map.deinit();
        view.low.deinit();
        view.high.deinit();
        view.explored.deinit();
    }

    pub fn resize(view: *View, dims: Dims) !void {
        try view.map.resize(dims);
        try view.low.resize(dims);
        try view.high.resize(dims);
        try view.explored.resize(dims.numTiles(), false);
    }
};

//pub fn isInFovEdge(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, view_height: ViewHeight) FovError!FovResult {
//    if (try isInFov(map, start_pos, end_pos, radius + 1, view_height)) {
//        if (start_pos.distanceMaximum(end_pos) == radius + 1) {
//            return FovResult.edge;
//        } else {
//            return FovResult.inside;
//        }
//    } else {
//        return FovResult.outside;
//    }
//}

pub fn isInFov(map: Map, start_pos: Pos, end_pos: Pos, view_height: ViewHeight) FovError!bool {
    // Make sure there is a clear path, but include walls (blocking position is the end_pos tile).
    var path_fov: ?Blocked = switch (view_height) {
        .low => pathing.pathBlockedFovLow(map, start_pos, end_pos),
        .high => pathing.pathBlockedFov(map, start_pos, end_pos),
    };

    if (path_fov) |blocked| {
        // If we get here, the position is in FOV but blocked.
        // The only blocked positions that are visible are at the end of the
        // path that are also block tiles (like a wall).
        return end_pos.eql(blocked.end_pos) and blocked.blocked_tile;
    } else {
        // Path not blocked, so in FoV.
        return true;
    }
}

// NOTE is this even useful? it would be for one-off FoV calculations.
//pub fn isInFovShadowcast(map: Map, start_pos: Pos, end_pos: Pos, allocator: Allocator) FovError!bool {
//    var pov: Pov = Pov.init(map.dims(), allocator);
//    defer pov.deinit();
//
//    try shadowcasting.computeFov(start_pos, map, &pov);
//    return pos.isVisible(end_pos);
//}

pub fn isInFovDirection(map: Map, start_pos: Pos, end_pos: Pos, dir: Direction, view_height: ViewHeight) FovError!bool {
    // TODO unit test whether we need this first case.
    if (start_pos.eql(end_pos)) {
        return true;
    } else if (math.visibleInDirection(start_pos, end_pos, dir)) {
        return try isInFov(map, start_pos, end_pos, view_height);
    } else {
        return false;
    }
}
