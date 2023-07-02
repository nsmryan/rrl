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
    ping,
    whirlWind,
    swift,

    pub fn class(skill: Skill) SkillClass {
        return switch (skill) {
            .grassWall, .GrassThrow, .grassBlade, .grassCover => .grass,
            .blink, .sprint, .roll => .body,
            .passWall, .rubble, .stoneThrow, .stoneSkin, .reform => .monolith,
            .ping => .body,
            .whirlWind, .swift => .wind,
        };
    }

    pub fn mode(skill: Skill) SkillMode {
        switch (skill) {
            .grassWall, .grassThrow, .grassBlade, .grassCover, .sprint, .roll, .passWall, .rubble, .stoneThrow, .reform, .swift => return .use,
            .blink, .stoneSkin => return .immediate,
            .ping, .whirlWind => return .cursor,
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
