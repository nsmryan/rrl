pub const entities = @import("core/entities.zig");
pub const level = @import("core/level.zig");
pub const items = @import("core/items.zig");
pub const skills = @import("core/skills.zig");
pub const talents = @import("core/talents.zig");
pub const movement = @import("core/movement.zig");
pub const config = @import("core/config.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
