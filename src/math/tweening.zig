const std = @import("std");

const easing = @import("easing.zig");
const Easing = easing.Easing;

pub const Tween = struct {
    from: f32,
    to: f32,
    duration: f32,
    elapsed: f32 = 0.0,
    ease: Easing,

    pub fn init(from: f32, to: f32, duration: f32, ease: Easing) Tween {
        return Tween{ .from = from, .to = to, .duration = duration, .ease = ease };
    }

    pub fn deltaTimeMs(tween: *Tween, ms: u64) void {
        tween.deltaTime(@intToFloat(f32, ms) / 1000.0);
    }

    pub fn deltaTime(tween: *Tween, dt: f32) void {
        tween.elapsed = std.math.min(tween.duration, tween.elapsed + dt);
    }

    pub fn done(tween: *const Tween) bool {
        return tween.elapsed == tween.duration;
    }

    pub fn value(tween: *const Tween) f32 {
        const percent = 1.0 - ((tween.duration - tween.elapsed) / tween.duration);
        const eased = tween.ease.ease(percent);
        if (tween.from < tween.to) {
            return tween.from + (tween.to - tween.from) * eased;
        } else {
            return tween.from - (tween.from - tween.to) * eased;
        }
    }

    pub fn reset(tween: *Tween) void {
        tween.elapsed = 0.0;
    }
};

test "basic tweening" {
    var tween = Tween.init(50.0, 70.0, 5.0, Easing.linearInterpolation);
    try std.testing.expectEqual(@as(f32, 50.0), tween.value());
    tween.deltaTime(2.5);
    try std.testing.expectEqual(@as(f32, 60.0), tween.value());
    tween.deltaTime(2.5);
    try std.testing.expectEqual(@as(f32, 70.0), tween.value());
}

test "backwards basic tweening" {
    var tween = Tween.init(255.0, 0.0, 5.0, Easing.linearInterpolation);
    try std.testing.expectEqual(@as(f32, 255.0), tween.value());
    tween.deltaTime(2.5);
    try std.testing.expectEqual(@as(f32, 255.0 / 2.0), tween.value());
    tween.deltaTime(2.5);
    try std.testing.expectEqual(@as(f32, 0.0), tween.value());
}
