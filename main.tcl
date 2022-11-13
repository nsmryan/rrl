#!/usr/bin/tclsh
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

Gui create gui
gui setBytes [Gui call init 0 $zigtcl::tclAllocator]

proc renderPeriodically { } {
    set result [gui call step]
    if { $result == 1 } {
        gui call draw
        after 100 renderPeriodically
    } else {
        global running
        set running 0
    }
}

#Comp(Pos) create compPos
#compPos setBytes [rrl::Comp(Pos) call init $zigtcl::tclAllocator]

renderPeriodically

vwait running
