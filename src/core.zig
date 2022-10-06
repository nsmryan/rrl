const std = @import("std");

pub const entities = @import("core/entities.zig");
pub usingnamespace entities;

pub const level = @import("core/level.zig");
pub usingnamespace level;

test "utils test set" {
    _ = @import("core/entities.zig");
    _ = @import("core/level.zig");
}
