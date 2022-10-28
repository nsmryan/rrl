pub const entities = @import("core/entities.zig");
pub const level = @import("core/level.zig");
pub const spawn = @import("core/spawn.zig");
pub const items = @import("core/items.zig");
pub const skills = @import("core/skills.zig");
pub const talents = @import("core/talents.zig");

test "utils test set" {
    _ = @import("core/entities.zig");
    _ = @import("core/level.zig");
    _ = @import("core/spawn.zig");
    _ = @import("core/items.zig");
    _ = @import("core/skills.zig");
    _ = @import("core/talents.zig");
}
