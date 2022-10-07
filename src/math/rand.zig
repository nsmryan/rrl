const std = @import("std");
const rand = std.rand;
const Random = rand.Random;

const Pos = @import("line").Pos;

pub fn rng_bool(rng: Random) bool {
    return rand.boolean(rng);
}

pub fn rng_trial(rng: Random, prob: f32) bool {
    return rand.float(rng) < prob;
}

pub fn rng_range(rng: Random, low: f32, high: f32) f32 {
    return (Random.float(rng) * (high - low)) + low;
}

pub fn rng_pos(rng: Random, bounds: Pos) Pos {
    const x = rng_range_i32(rng, 0, bounds.x);
    const y = rng_range_i32(rng, 0, bounds.y);
    return Pos.new(x, y);
}

pub fn rng_range_i32(rng: Random, low: i32, high: i32) i32 {
    if (low == high) {
        return low;
    } else {
        return Random.intRangeAtMost(rng, i32, low, high);
    }
}

pub fn rng_range_u32(rng: Random, low: u32, high: u32) u32 {
    if (low == high) {
        return low;
    } else {
        return Random.intRangeAtMost(rng, u32, low, high);
    }
}

pub fn choose(comptime T: type, rng: Random, items: []const T) ?T {
    if (items.len > 0) {
        return items[rng_range_u32(rng, 0, items.len)];
    } else {
        return null;
    }
}
