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

rrl::Map create map
map setBytes [rrl::Map call fromDims 3 3 $zigtcl::tclAllocator]
map call set [rrl::Pos call init 1 1] [rrl::Tile call shortLeftAndDownWall]

rrl::Display create disp
disp setBytes [rrl::Display call init 800 600]

disp call push [rrl::DrawCmd call text "hello, tcl drawing!" [rrl::Pos call init 10 10] [rrl::Color call white] 1.0]
disp call present

proc makeTileSprite { name } {
    global tileLocations 
    set tiles [disp call lookupSpritekey rustrogueliketiles]
    set key [dict get $tileLocations $name]
    set tileSprite [rrl::Sprite call init $key $tiles]
    return $tileSprite
}
set floorSprite [makeTileSprite open_tile]
set downWall [makeTileSprite down_intertile_wall]
set leftWall [makeTileSprite left_intertile_wall]


rrl::Tile create t
rrl::Wall create w

#t setBytes [map call get [p bytes]]

proc renderMap { } {
    global disp m floorSprite downWall leftWall

    set black [rrl::Color call black]
    for { set y 0 } { $y < [map get height] } { incr y } {
        for { set x 0 } { $x < [map get width] } { incr x } {
            set pos [rrl::Pos call init $x $y]
            set tileCmd [rrl::DrawCmd call sprite $floorSprite $black $pos]
            disp call push $tileCmd

            t setBytes [map call get $pos]

            w setBytes [t get down]
            set downName [rrl::Height name [w get height]]
            if { $downName == "short" } {
                set tileCmd [rrl::DrawCmd call sprite $downWall $black $pos]
                disp call push $tileCmd
            }

            w setBytes [t get left]
            set leftName [rrl::Height name [w get height]]
            if { $leftName == "short" } {
                set tileCmd [rrl::DrawCmd call sprite $leftWall $black $pos]
                disp call push $tileCmd
            }
        }
    }

    disp call present
}


proc renderMapPeriodically { } {
    renderMap
    after 100 renderMapPeriodically
}

renderMapPeriodically
