pub const entities = @import("entities.zig");
pub const level = @import("level.zig");
pub const items = @import("items.zig");
pub const skills = @import("skills.zig");
pub const talents = @import("talents.zig");
pub const movement = @import("movement.zig");
pub const config = @import("config.zig");
pub const fov = @import("fov.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
