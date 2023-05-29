const std = @import("std");

const math = @import("math");
const Tween = math.tweening.Tween;
const Color = math.utils.Color;
const Pos = math.pos.Pos;

const drawing = @import("drawing");
const sprite = drawing.sprite;
const Sprite = sprite.Sprite;
const Animation = drawing.animation.Animation;
const DrawCmd = drawing.drawcmd.DrawCmd;

pub const Effect = union(enum) {
    animation: Animation,
    highlight: struct { pos: Pos, color: Color, alpha: Tween, delay: u64 },
    outline: struct { pos: Pos, color: Color, alpha: Tween, delay: u64 },
    particle: struct { start_x: f32, end_x: f32, y: f32, duration: u64, time: u64, sprite: Sprite },

    pub fn animationEffect(animation_field: Animation) Effect {
        return Effect{ .animation = animation_field };
    }

    pub fn highlightEffect(pos: Pos, color: Color, alpha: Tween, delay_ms: u64) Effect {
        return Effect{ .highlight = .{ .pos = pos, .color = color, .alpha = alpha, .delay = delay_ms } };
    }

    pub fn outlineEffect(pos: Pos, color: Color, alpha: Tween, delay_ms: u64) Effect {
        return Effect{ .outline = .{ .pos = pos, .color = color, .alpha = alpha, .delay = delay_ms } };
    }

    // Steps effect forward one frame, returns true if still running.
    pub fn step(effect: *Effect, dt: u64) bool {
        switch (effect.*) {
            .animation => |*anim| {
                return anim.step(dt);
            },

            .highlight => |*args| {
                const pair = math.utils.saturatedSubtraction(args.delay, dt);
                args.delay = pair.result;
                if (args.delay == 0) {
                    args.alpha.deltaTimeMs(pair.delta);
                    return !args.alpha.done();
                } else {
                    return true;
                }
            },

            .outline => |*args| {
                const pair = math.utils.saturatedSubtraction(args.delay, dt);
                args.delay = pair.result;
                if (args.delay == 0) {
                    args.alpha.deltaTimeMs(pair.delta);
                    return !args.alpha.done();
                } else {
                    return true;
                }
            },

            .particle => |*args| {
                args.time += dt;
                return args.time <= args.duration;
            },
        }
    }

    pub fn draw(effect: *const Effect) ?DrawCmd {
        switch (effect.*) {
            .animation => |anim| {
                return anim.draw();
            },

            .highlight => |args| {
                if (args.delay == 0) {
                    var color = args.color;
                    color.a = @floatToInt(u8, args.alpha.value() * 255.0);
                    return DrawCmd.highlightTile(args.pos, color);
                }
            },

            .outline => |args| {
                if (args.delay == 0) {
                    var color = args.color;
                    color.a = @floatToInt(u8, args.alpha.value() * 255.0);
                    return DrawCmd.outlineTile(args.pos, color);
                }
            },

            .particle => |args| {
                const percent = (@intToFloat(f32, args.time) / @intToFloat(f32, args.duration));
                const x = args.start_x + ((args.end_x - args.start_x) * percent);
                var color = Color.white();
                color.a = @floatToInt(u8, 255.0 * (1.0 - percent));
                return DrawCmd.spriteFloat(args.sprite, color, x, args.y, 0.1, 0.1);
            },
        }
        return null;
    }
};
