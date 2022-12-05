const print = @import("std").debug.print;

const math = @import("math");
const Tween = math.tweening.Tween;
const Pos = math.pos.Pos;
const Color = math.utils.Color;

const sprite = @import("sprite.zig");
const Sprite = sprite.Sprite;
const SpriteAnimation = sprite.SpriteAnimation;

const DrawCmd = @import("drawcmd.zig").DrawCmd;

pub const Animation = struct {
    sprite_anim: SpriteAnimation,
    random: bool = false,
    repeat: bool = false,
    color: Color,
    position: Pos,
    alpha: ?Tween = null,
    x: ?Tween = null,
    y: ?Tween = null,

    pub fn init(sprite_anim: SpriteAnimation, color: Color, position: Pos) Animation {
        return Animation{ .sprite_anim = sprite_anim, .color = color, .position = position };
    }

    pub fn randomize(anim: Animation) Animation {
        anim.random = true;
        return anim;
    }

    pub fn alpha(anim: Animation, tween: Tween) Animation {
        anim.alpha = tween;
        return anim;
    }

    pub fn x(anim: Animation, tween: Tween) Animation {
        anim.x = tween;
        return anim;
    }

    pub fn y(anim: Animation, tween: Tween) Animation {
        anim.y = tween;
        return anim;
    }

    pub fn doneTweening(anim: *const Animation) bool {
        return anim.x == null and anim.y == null and anim.alpha == null;
    }

    pub fn step(anim: *Animation, dt: u64) bool {
        if (anim.alpha) |*alpha_ptr| {
            if (alpha_ptr.done()) {
                anim.alpha = null;
            } else {
                alpha_ptr.deltaTimeMs(dt);
            }
        }
        if (anim.x) |*x_ptr| {
            if (x_ptr.done()) {
                anim.x = null;
            } else {
                x_ptr.deltaTimeMs(dt);
            }
        }
        if (anim.y) |*y_ptr| {
            if (y_ptr.done()) {
                anim.y = null;
            } else {
                y_ptr.deltaTimeMs(dt);
            }
        }
        anim.sprite_anim.step(@intToFloat(f32, dt) / 1000.0);

        return !(anim.sprite_anim.looped and !anim.repeat);
    }

    pub fn draw(anim: *const Animation) DrawCmd {
        var color = anim.color;
        if (anim.alpha) |alpha_ptr| {
            color.a = @floatToInt(u8, alpha_ptr.value());
        }

        if (anim.x != null or anim.y != null) {
            var pos_x: f32 = @intToFloat(f32, anim.position.x);
            if (anim.x) |x_ptr| {
                pos_x = x_ptr.value();
            }

            var pos_y: f32 = @intToFloat(f32, anim.position.y);
            if (anim.y) |y_ptr| {
                pos_y = y_ptr.value();
            }

            return DrawCmd.spriteFloat(anim.sprite_anim.current(), color, pos_x, pos_y, 1.0, 1.0);
        } else {
            return DrawCmd.sprite(anim.sprite_anim.current(), color, anim.position);
        }
    }
};
