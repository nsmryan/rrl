const std = @import("std");

pub const Timer = struct {
    period: u64,
    time_left: u64,

    pub fn init(period: u64) Timer {
        return Timer{ .period = period, .time_left = 0 };
    }

    pub fn step(timer: *Timer, dt: u64) u64 {
        var rollovers: u64 = 0;
        if (timer.period == 0) {
            return rollovers;
        } else if (timer.time_left + dt >= timer.period) {
            rollovers = (timer.time_left + dt) / timer.period;
        }
        timer.time_left = (timer.time_left + dt) % timer.period;
        return rollovers;
    }
};

test "timer basics" {
    var timer = Timer.init(1000);
    try std.testing.expectEqual(@as(u64, 0), timer.step(999));
    try std.testing.expectEqual(@as(u64, 1), timer.step(1));
    try std.testing.expectEqual(@as(u64, 1), timer.step(1000));
    try std.testing.expectEqual(@as(u64, 0), timer.step(999));
    try std.testing.expectEqual(@as(u64, 2), timer.step(2000));
    try std.testing.expectEqual(@as(u64, 1), timer.step(1));
}
