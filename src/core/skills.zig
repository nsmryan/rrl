pub const Skill = enum {
    grassWall,
    grassThrow,
    grassBlade,
    grassCover,
    blink,
    sprint,
    roll,
    passWall,
    rubble,
    stoneThrow,
    stoneSkin,
    reform,
    push,
    traps,
    illuminate,
    ping,
    passThrough,
    whirlWind,
    swift,

    pub fn class(skill: Skill) SkillClass {
        return switch (skill) {
            .grassWall, .GrassThrow, .grassBlade, .grassCover => .grass,
            .blink, .sprint, .roll => .body,
            .passWall, .rubble, .stoneThrow, .stoneSkin, .reform, .push, .traps => .monolith,
            .illuminate, .ping => .body,
            .passThrough, .whirlWind, .swift => .wind,
        };
    }

    pub fn mode(skill: Skill) SkillMode {
        switch (skill) {
            .grassWall, .grassThrow, .grassBlade, .grassCover, .sprint, .roll, .passWall, .rubble, .stoneThrow, .reform, .push, .traps, .illuminate, .passThrough, .swift => .use,
            .blink, .stoneSkin => .immediate,
            .ping, .whirlWind => .cursor,
        }
    }
};

pub const SkillMode = enum {
    use,
    cursor,
    immediate,
};

pub const SkillClass = enum {
    body,
    grass,
    monolith,
    wind,
};
