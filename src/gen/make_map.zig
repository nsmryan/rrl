pub const MapLoadConfig = union(enum) {
    random,
    testMap,
    testWall,
    testColumns,
    empty,
    testSmoke,
    testCorner,
    testPlayer,
    testArmil,
    testVaults,
    testTraps,
    vaultFile: []u8,
    procGen: []u8,
    testGen: []u8,
};

pub const MapGenType = union(enum) {
    island,
    wallTest,
    cornerTest,
    playerTest,
    fromFile: []u8,
    animations,
};
