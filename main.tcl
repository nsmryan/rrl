load zig-out/lib/librrl.so
package require rrl
namespace import rrl::*


set locFile [open data/tile_locations.txt r]
set indexToName [read $locFile]
close $locFile

set tileLocations [list]
foreach { num name } $indexToName {
    dict set tileLocations $name [expr $num - 1]
}

Map create map
map setBytes [Map call fromDims 3 3 $zigtcl::tclAllocator]
map call set [Pos call init 1 1] [Tile call shortLeftAndDownWall]

Entities create entities
entities setBytes [Entities call init $zigtcl::tclAllocator]
set playerId [spawn call spawnPlayer [entities ptr] [Pos call init 2 2]]

Display create disp
disp setBytes [Display call init 800 600]

disp call push [DrawCmd call text "hello, tcl drawing!" [Pos call init 10 10] [Color call white] 1.0]
disp call present

proc makeTileSprite { name } {
    global tileLocations 
    set tiles [disp call lookupSpritekey rustrogueliketiles]
    set key [dict get $tileLocations $name]
    set tileSprite [Sprite call init $key $tiles]
    return $tileSprite
}
set floorSprite [makeTileSprite open_tile]
set downWall [makeTileSprite down_intertile_wall]
set leftWall [makeTileSprite left_intertile_wall]


Tile create t
Wall create w

#t setBytes [map call get [p bytes]]

proc renderMap { } {
    global floorSprite downWall leftWall

    set black [Color call black]
    for { set y 0 } { $y < [map get height] } { incr y } {
        for { set x 0 } { $x < [map get width] } { incr x } {
            set pos [Pos call init $x $y]
            set tileCmd [DrawCmd call sprite $floorSprite $black $pos]
            disp call push $tileCmd

            t setBytes [map call get $pos]

            w setBytes [t get down]
            set downName [Height name [w get height]]
            if { $downName == "short" } {
                set tileCmd [DrawCmd call sprite $downWall $black $pos]
                disp call push $tileCmd
            }

            w setBytes [t get left]
            set leftName [Height name [w get height]]
            if { $leftName == "short" } {
                set tileCmd [DrawCmd call sprite $leftWall $black $pos]
                disp call push $tileCmd
            }
        }
    }

    disp call present
}

proc renderEntities { } {
    global black
    set playerSprite [makeTileSprite player_standing_down]
    disp call push [DrawCmd call sprite $playerSprite $block $pos]
}


proc renderMapPeriodically { } {
    renderMap
    after 100 renderMapPeriodically
}

Comp(Pos) create compPos
compPos setBytes [rrl::Comp(Pos) call init $zigtcl::tclAllocator]

renderMapPeriodically
