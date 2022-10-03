
pub fn isInFovEdge(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool) FovResult {
    if (map.isInFov(start_pos, end_pos, radius + 1, low)) {
        if (distanceMaximum(start_pos, end_pos) == radius + 1) {
            return FovResult.edge;
        } else {
            return FovResult.inside;
        }
    } else {
        return FovResult.outside;
    }
}

pub fn isInFov(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool) bool {
    var in_fov = false;

    // check that the position is within the max view distance.
    if (distance_maximum(start_pos, end_pos) <= radius) {
        if (self.is_in_fov_shadowcast(start_pos, end_pos)) {
            // so far, the position is in fov
            in_fov = true;

            // make sure there is a clear path, but allow the player to
            // see walls (blocking position is the end_pos tile)
            var path_fov = undefined;
            if (low) {
                path_fov = self.pathBlockedFovLow(start_pos, end_pos);
            } else {
                path_fov = self.pathBlockedFov(start_pos, end_pos);
            }

            if (path_fov) |blocked| {
                // If we get here, the position is in FOV but blocked.
                // The only blocked positions that are visible are at the end of the
                // path and also block tiles (like a wall).
                // TODO to hide in tall grass
                //in_fov = end_pos == blocked.end_pos && blocked.blocked_tile && self[end_pos].surface != Surface::Grass;
                in_fov = end_pos == blocked.end_pos and blocked.blocked_tile;
            } 
        }
    }

    return in_fov;
}

pub fn is_in_fov_shadowcast(map: Map, start_pos: Pos, end_pos: Pos) bool {
    if (self.fov_cache.borrow_mut().get(&start_pos)) |visible| {
        return visible.contains(&end_pos);
    }

    // NOTE(perf) this should be correct- shadowcasting is symmetrical, so 
    // we either need a precomputed start-to-end or end-to-start
    // calculation, but not both.
    if (self.fov_cache.borrow_mut().get(&end_pos)) |visible| {
        return visible.contains(&start_pos);
    }

    // NOTE(perf) this pre-allocation speeds up FOV significantly
    var visible_positions = Vec.with_capacity(120);

    var mark_fov = |sym_pos: SymPos| {
        let pos = Pos.init(sym_pos.0 as i32, sym_pos.1 as i32);
        visible_positions.push(pos);
    };

    var is_blocking = |sym_pos: SymPos| {
        let pos = Pos.init(sym_pos.0 as i32, sym_pos.1 as i32);

        if !self.is_within_bounds(pos) {
            return true;
        }

        let blocked_sight = self[pos].block_sight;

        return blocked_sight;
    };

    compute_fov((start_pos.x as isize, start_pos.y as isize), &mut is_blocking, &mut mark_fov);

    const in_fov = visible_positions.contains(&end_pos);
    self.fov_cache.borrow_mut().insert(start_pos, visible_positions);

    return in_fov;
}

pub fn isInFovDirection(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, dir: Direction, low: bool) bool {
    if (start_pos == end_pos) {
        return true;
    } else if (self.isInFov(start_pos, end_pos, radius, low)) {
        return visibleInDirection(start_pos, end_pos, dir);
    } else {
        return false;
    }
}

