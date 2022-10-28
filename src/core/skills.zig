const EntityClass = @import("entities.zig").EntityClass;

pub const Skill = enum {
    grassWall,
    grassThrow,
    grassBlade,
    grassShoes,
    grassCover,
    blink,
    swap,
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
    heal,
    farSight,
    ping,
    passThrough,
    whirlWind,
    swift,

    pub fn class(self: Skill) EntityClass {
        switch (self) {
            Skill.grassWall => EntityClass.grass,
            Skill.grassThrow => EntityClass.grass,
            Skill.grassBlade => EntityClass.grass,
            Skill.grassShoes => EntityClass.grass,
            Skill.grassCover => EntityClass.grass,
            Skill.blink => EntityClass.body,
            Skill.swap => EntityClass.body,
            Skill.sprint => EntityClass.body,
            Skill.roll => EntityClass.body,
            Skill.passWall => EntityClass.monolith,
            Skill.rubble => EntityClass.monolith,
            Skill.stoneThrow => EntityClass.monolith,
            Skill.stoneSkin => EntityClass.monolith,
            Skill.reform => EntityClass.monolith,
            Skill.push => EntityClass.monolith,
            Skill.traps => EntityClass.monolith,
            Skill.illuminate => EntityClass.body,
            Skill.heal => EntityClass.body,
            Skill.farSight => EntityClass.body,
            Skill.ping => EntityClass.body,
            Skill.passThrough => EntityClass.wind,
            Skill.whirlWind => EntityClass.wind,
            Skill.swift => EntityClass.wind,
        }
    }

    pub fn mode(self: Skill) SkillMode {
        switch (self) {
            Skill.GrassWall => SkillMode.direction,
            Skill.GrassThrow => SkillMode.direction,
            Skill.GrassBlade => SkillMode.direction,
            Skill.GrassShoes => SkillMode.immediate,
            Skill.GrassCover => SkillMode.direction,
            Skill.Blink => SkillMode.immediate,
            Skill.Swap => SkillMode.cursor,
            Skill.Sprint => SkillMode.direction,
            Skill.Roll => SkillMode.direction,
            Skill.PassWall => SkillMode.direction,
            Skill.Rubble => SkillMode.direction,
            Skill.StoneThrow => SkillMode.direction,
            Skill.StoneSkin => SkillMode.immediate,
            Skill.Reform => SkillMode.direction,
            Skill.Push => SkillMode.direction,
            Skill.Traps => SkillMode.direction,
            Skill.Illuminate => SkillMode.direction,
            Skill.Heal => SkillMode.immediate,
            Skill.FarSight => SkillMode.immediate,
            Skill.Ping => SkillMode.cursor,
            Skill.PassThrough => SkillMode.direction,
            Skill.WhirlWind => SkillMode.cursor,
            Skill.Swift => SkillMode.direction,
        }
    }
};

pub const SkillMode = enum {
    direction,
    cursor,
    immediate,
};
