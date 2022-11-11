load zig-out/lib/librrl.so
package require rrl
namespace import rrl::*


proc pos { x y } {
    return [Pos call init $x $y]
}

proc moveTo { x y } {
    global playerId
    Comp(Pos) with [entities ptr pos] call set $playerId [pos $x $y]]
}

set playerId 0

set locFile [open data/tile_locations.txt r]
set indexToName [read $locFile]
close $locFile

set tileLocations [list]
foreach { num name } $indexToName {
    dict set tileLocations $name [expr $num - 1]
}

Game create game init 0 $zigtcl::tclAllocator

Map create map
map setBytes [Map call fromDims 3 3 $zigtcl::tclAllocator]
map call set [pos 1 1] [Tile call shortLeftAndDownWall]


Config create config fromFile data/config.txt

Entities create entities
entities setBytes [Entities call init $zigtcl::tclAllocator]
spawn call spawnPlayer [entities ptr] [config ptr]

Display create disp
disp setBytes [Display call init 800 600 $zigtcl::tclAllocator]

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

proc setPlayerPos { pos } {
    global playerId
    Comp(Pos) with [entities ptr pos] call set $playerId $pos]
}

proc renderMap { } {
    global floorSprite downWall leftWall

    set black [Color call black] 
    for { set y 0 } { $y < [map get height] } { incr y } { for { set x 0 } { $x < [map get width] } { incr x } {
            set pos [pos $x $y]
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
}

proc renderEntities { } {
    global playerId

    set black [Color call black]
    set sheet [disp call lookupSpritekey player_standing_down]
    set playerSprite [Sprite call init 0 $sheet]

    set playerPos [Comp(Pos) with [entities ptr pos] call get $playerId]
    Pos create p
    p setBytes $playerPos

    set playerCmd [DrawCmd call sprite $playerSprite $black $playerPos]
    disp call push $playerCmd
}


proc renderPeriodically { } {
    renderMap
    renderEntities
    disp call present
    after 100 renderPeriodically
}

#Comp(Pos) create compPos
#compPos setBytes [rrl::Comp(Pos) call init $zigtcl::tclAllocator]

renderPeriodically

vwait forever
