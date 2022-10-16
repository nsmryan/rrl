pub const entities = @import("core/entities.zig");
pub const level = @import("core/level.zig");
pub const spawn = @import("core/spawn.zig");

test "utils test set" {
    _ = @import("core/entities.zig");
    _ = @import("core/level.zig");
    _ = @import("core/spawn.zig");
}
