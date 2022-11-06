pub const MoveMode = enum {
    sneak,
    walk,
    run,

    pub fn increase(self: MoveMode) MoveMode {
        switch (self) {
            MoveMode.sneak => MoveMode.walk,
            MoveMode.run => MoveMode.run,
            MoveMode.walk => MoveMode.run,
        }
    }

    pub fn decrease(self: MoveMode) MoveMode {
        switch (self) {
            MoveMode.sneak => MoveMode.sneak,
            MoveMode.run => MoveMode.walk,
            MoveMode.walk => MoveMode.sneak,
        }
    }

    pub fn moveAmount(self: MoveMode) usize {
        return switch (self) {
            .sneak => 1,
            .walk => 1,
            .run => 2,
        };
    }
};
