// This file is based on the https://github.com/warrenm/AHEasing codebase.
// The original header is reproduced below as attribution to the original author.
//
//  easing.c
//
//  Copyright (c) 2011, Auerhaus Development, LLC
//
//  This program is free software. It comes without any warranty, to
//  the extent permitted by applicable law. You can redistribute it
//  and/or modify it under the terms of the Do What The Fuck You Want
//  To Public License, Version 2, as published by Sam Hocevar. See
//  http://sam.zoy.org/wtfpl/COPYING for more details.
//

const std = @import("std");

pub const Easing = enum {
    linearInterpolation,
    quadraticEaseIn,
    quadraticEaseOut,
    quadraticEaseInOut,
    cubicEaseIn,
    cubicEaseOut,
    cubicEaseInOut,
    quarticEaseIn,
    quarticEaseOut,
    quarticEaseInOut,
    quinticEaseIn,
    quinticEaseOut,
    quinticEaseInOut,
    sineEaseIn,
    sineEaseOut,
    sineEaseInOut,
    circularEaseIn,
    circularEaseOut,
    circularEaseInOut,
    exponentialEaseIn,
    exponentialEaseOut,
    exponentialEaseInOut,
    elasticEaseIn,
    elasticEaseOut,
    elasticEaseInOut,
    backEaseIn,
    backEaseOut,
    backEaseInOut,
    bounceEaseIn,
    bounceEaseOut,
    bounceEaseInOut,

    pub fn ease(easing: Easing, p: f32) f32 {
        return switch (easing) {
            .linearInterpolation => linearInterpolation(p),
            .quadraticEaseIn => quadraticEaseIn(p),
            .quadraticEaseOut => quadraticEaseOut(p),
            .quadraticEaseInOut => quadraticEaseInOut(p),
            .cubicEaseIn => cubicEaseIn(p),
            .cubicEaseOut => cubicEaseOut(p),
            .cubicEaseInOut => cubicEaseInOut(p),
            .quarticEaseIn => quarticEaseIn(p),
            .quarticEaseOut => quarticEaseOut(p),
            .quarticEaseInOut => quarticEaseInOut(p),
            .quinticEaseIn => quinticEaseIn(p),
            .quinticEaseOut => quinticEaseOut(p),
            .quinticEaseInOut => quinticEaseInOut(p),
            .sineEaseIn => sineEaseIn(p),
            .sineEaseOut => sineEaseOut(p),
            .sineEaseInOut => sineEaseInOut(p),
            .circularEaseIn => circularEaseIn(p),
            .circularEaseOut => circularEaseOut(p),
            .circularEaseInOut => circularEaseInOut(p),
            .exponentialEaseIn => exponentialEaseIn(p),
            .exponentialEaseOut => exponentialEaseOut(p),
            .exponentialEaseInOut => exponentialEaseInOut(p),
            .elasticEaseIn => elasticEaseIn(p),
            .elasticEaseOut => elasticEaseOut(p),
            .elasticEaseInOut => elasticEaseInOut(p),
            .backEaseIn => backEaseIn(p),
            .backEaseOut => backEaseOut(p),
            .backEaseInOut => backEaseInOut(p),
            .bounceEaseIn => bounceEaseIn(p),
            .bounceEaseOut => bounceEaseOut(p),
            .bounceEaseInOut => bounceEaseInOut(p),
        };
    }
};

// Modeled after the line y = x
pub fn linearInterpolation(p: f32) f32 {
    return p;
}

// Modeled after the parabola y = x^2
pub fn quadraticEaseIn(p: f32) f32 {
    return p * p;
}

// Modeled after the parabola y = -x^2 + 2x
pub fn quadraticEaseOut(p: f32) f32 {
    return -(p * (p - 2));
}

// Modeled after the piecewise quadratic
// y = (1/2)((2x)^2)             ; [0, 0.5)
// y = -(1/2)((2x-1)*(2x-3) - 1) ; [0.5, 1]
pub fn quadraticEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 2 * p * p;
    } else {
        return (-2 * p * p) + (4 * p) - 1;
    }
}

// Modeled after the cubic y = x^3
pub fn cubicEaseIn(p: f32) f32 {
    return p * p * p;
}

// Modeled after the cubic y = (x - 1)^3 + 1
pub fn cubicEaseOut(p: f32) f32 {
    const f: f32 = (p - 1);
    return f * f * f + 1;
}

// Modeled after the piecewise cubic
// y = (1/2)((2x)^3)       ; [0, 0.5)
// y = (1/2)((2x-2)^3 + 2) ; [0.5, 1]
pub fn cubicEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 4 * p * p * p;
    } else {
        const f: f32 = ((2 * p) - 2);
        return 0.5 * f * f * f + 1;
    }
}

// Modeled after the quartic x^4
pub fn quarticEaseIn(p: f32) f32 {
    return p * p * p * p;
}

// Modeled after the quartic y = 1 - (x - 1)^4
pub fn quarticEaseOut(p: f32) f32 {
    const f: f32 = (p - 1);
    return f * f * f * (1 - p) + 1;
}

// Modeled after the piecewise quartic
// y = (1/2)((2x)^4)        ; [0, 0.5)
// y = -(1/2)((2x-2)^4 - 2) ; [0.5, 1]
pub fn quarticEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 8 * p * p * p * p;
    } else {
        const f: f32 = (p - 1);
        return -8 * f * f * f * f + 1;
    }
}

// Modeled after the quintic y = x^5
pub fn quinticEaseIn(p: f32) f32 {
    return p * p * p * p * p;
}

// Modeled after the quintic y = (x - 1)^5 + 1
pub fn quinticEaseOut(p: f32) f32 {
    const f: f32 = (p - 1);
    return f * f * f * f * f + 1;
}

// Modeled after the piecewise quintic
// y = (1/2)((2x)^5)       ; [0, 0.5)
// y = (1/2)((2x-2)^5 + 2) ; [0.5, 1]
pub fn quinticEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 16 * p * p * p * p * p;
    } else {
        const f: f32 = ((2 * p) - 2);
        return 0.5 * f * f * f * f * f + 1;
    }
}

// Modeled after quarter-cycle of sine wave
pub fn sineEaseIn(p: f32) f32 {
    return std.math.sin((p - 1) * (std.math.pi / 2.0)) + 1;
}

// Modeled after quarter-cycle of sine wave (different phase)
pub fn sineEaseOut(p: f32) f32 {
    return std.math.sin(p * (std.math.pi / 2.0));
}

// Modeled after half sine wave
pub fn sineEaseInOut(p: f32) f32 {
    return 0.5 * (1 - std.math.cos(p * std.math.pi));
}

// Modeled after shifted quadrant IV of unit circle
pub fn circularEaseIn(p: f32) f32 {
    return 1 - std.math.sqrt(1 - (p * p));
}

// Modeled after shifted quadrant II of unit circle
pub fn circularEaseOut(p: f32) f32 {
    return std.math.sqrt((2 - p) * p);
}

// Modeled after the piecewise circular function
// y = (1/2)(1 - sqrt(1 - 4x^2))           ; [0, 0.5)
// y = (1/2)(sqrt(-(2x - 3)*(2x - 1)) + 1) ; [0.5, 1]
pub fn circularEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 0.5 * (1 - std.math.sqrt(1 - 4 * (p * p)));
    } else {
        return 0.5 * (std.math.sqrt(-((2 * p) - 3) * ((2 * p) - 1)) + 1);
    }
}

// Modeled after the exponential function y = 2^(10(x - 1))
pub fn exponentialEaseIn(p: f32) f32 {
    if (p == 0.0) {
        return p;
    } else {
        return std.math.pow(f32, 2, 10 * (p - 1));
    }
}

// Modeled after the exponential function y = -2^(-10x) + 1
pub fn exponentialEaseOut(p: f32) f32 {
    if (p == 1.0) {
        return p;
    } else {
        return 1 - std.math.pow(f32, 2, -10 * p);
    }
}

// Modeled after the piecewise exponential
// y = (1/2)2^(10(2x - 1))         ; [0,0.5)
// y = -(1/2)*2^(-10(2x - 1))) + 1 ; [0.5,1]
pub fn exponentialEaseInOut(p: f32) f32 {
    if (p == 0.0 or p == 1.0) {
        return p;
    }

    if (p < 0.5) {
        return 0.5 * std.math.pow(f32, 2, (20 * p) - 10);
    } else {
        return -0.5 * std.math.pow(f32, 2, (-20 * p) + 10) + 1;
    }
}

// Modeled after the damped sine wave y = sin(13pi/2*x)*pow(2, 10 * (x - 1))
pub fn elasticEaseIn(p: f32) f32 {
    return std.math.sin(13 * (std.math.pi / 2.0) * p) * std.math.pow(f32, 2, 10 * (p - 1));
}

// Modeled after the damped sine wave y = sin(-13pi/2*(x + 1))*pow(2, -10x) + 1
pub fn elasticEaseOut(p: f32) f32 {
    return std.math.sin(-13 * (std.math.pi / 2.0) * (p + 1)) * std.math.pow(f32, 2, -10 * p) + 1;
}

// Modeled after the piecewise exponentially-damped sine wave:
// y = (1/2)*sin(13pi/2*(2*x))*pow(2, 10 * ((2*x) - 1))      ; [0,0.5)
// y = (1/2)*(sin(-13pi/2*((2x-1)+1))*pow(2,-10(2*x-1)) + 2) ; [0.5, 1]
pub fn elasticEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 0.5 * std.math.sin(13 * (std.math.pi / 2.0) * (2 * p)) * std.math.pow(f32, 2, 10 * ((2 * p) - 1));
    } else {
        return 0.5 * (std.math.sin(-13 * (std.math.pi / 2.0) * ((2 * p - 1) + 1)) * std.math.pow(f32, 2, -10 * (2 * p - 1)) + 2);
    }
}

// Modeled after the overshooting cubic y = x^3-x*sin(x*pi)
pub fn backEaseIn(p: f32) f32 {
    return p * p * p - p * std.math.sin(p * std.math.pi);
}

// Modeled after overshooting cubic y = 1-((1-x)^3-(1-x)*sin((1-x)*pi))
pub fn backEaseOut(p: f32) f32 {
    const f: f32 = (1 - p);
    return 1 - (f * f * f - f * std.math.sin(f * std.math.pi));
}

// Modeled after the piecewise overshooting cubic function:
// y = (1/2)*((2x)^3-(2x)*sin(2*x*pi))           ; [0, 0.5)
// y = (1/2)*(1-((1-x)^3-(1-x)*sin((1-x)*pi))+1) ; [0.5, 1]
pub fn backEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        const f: f32 = 2 * p;
        return 0.5 * (f * f * f - f * std.math.sin(f * std.math.pi));
    } else {
        const f: f32 = (1 - (2 * p - 1));
        return 0.5 * (1 - (f * f * f - f * std.math.sin(f * std.math.pi))) + 0.5;
    }
}

pub fn bounceEaseIn(p: f32) f32 {
    return 1 - bounceEaseOut(1 - p);
}

pub fn bounceEaseOut(p: f32) f32 {
    if (p < 4.0 / 11.0) {
        return (121.0 * p * p) / 16.0;
    } else if (p < 8.0 / 11.0) {
        return (363.0 / 40.0 * p * p) - (99.0 / 10.0 * p) + 17.0 / 5.0;
    } else if (p < 9.0 / 10.0) {
        return (4356.0 / 361.0 * p * p) - (35442.0 / 1805.0 * p) + 16061.0 / 1805.0;
    } else {
        return (54.0 / 5.0 * p * p) - (513.0 / 25.0 * p) + 268.0 / 25.0;
    }
}

pub fn bounceEaseInOut(p: f32) f32 {
    if (p < 0.5) {
        return 0.5 * bounceEaseIn(p * 2);
    } else {
        return 0.5 * bounceEaseOut(p * 2 - 1) + 0.5;
    }
}
