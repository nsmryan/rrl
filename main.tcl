#!/usr/bin/tclsh
load zig-out/lib/librrl.so
package require rrl
namespace import rrl::*


# Currently to get the player X position.
#Pos create pos
#pos bytes [Comp(Pos) with [Entities with [Level with [Game with [gui ptr game] ptr level] ptr entities] ptr pos] call get 0]
#pos get x

proc pos { x y } {
    return [Pos call init $x $y]
}

set playerId 0

Gui create gui
gui setBytes [Gui call init 0 0 $zigtcl::tclAllocator]
Game with [gui ptr game] call startLevel 9 9
gui call resolveMessages

InputEvent create event
proc keyDown { chr } {
    event variant char $chr [KeyDir value down]
    gui call inputEvent [event bytes] 0
}

proc keyUp { chr } {
    event variant char $chr [KeyDir value up]
    gui call inputEvent [event bytes] 0
}

proc key { chr } {
    scan $chr %c value
    keyDown $value
    keyUp $value
}

proc space { } {
    keyUp 32
    keyDown 32
}

proc esc { } {
    keyUp 27
    keyDown 27
}

set startupTicks [clock milliseconds]
proc ticks { } {
    global startupTicks
    return [expr [clock milliseconds] - $startupTicks]
}

# Translates
#pos bytes [Comp(Pos) with [Entities with [Level with [Game with [gui ptr game] ptr level] ptr entities] ptr pos] call get 0]
#pos get x
# into 
#pos bytes [Comp(Pos) with [ptr [gui ptr] Gui game Game level Level entities Entities pos] call get 0]
proc ptr { ptr args } { 
    foreach { type field } $args {
        set ptr [$type with $ptr ptr $field]
    }
    return $ptr
}

# Get a component from a particular entity by name.
proc getValue { typ name id } {
    return [Comp($typ) with [ptr [gui ptr] Gui game Game level Level entities Entities $name] call get $id]
}

proc setValue { typ name id value } {
    return [Comp($typ) with [ptr [gui ptr] Gui game Game level Level entities Entities $name] call set $id $value]
}


proc mkKey { name value } { proc $name { } "key $value" }
mkKey up 8
mkKey down 2
mkKey right 6
mkKey left 4
mkKey upLeft 7
mkKey upRight 9
mkKey downLeft 1
mkKey downRight 3

proc run { dir } {
    event variant shift [KeyDir value down]
    gui call inputEvent [event bytes] 0
    $dir
    event variant shift [KeyDir value up]
    gui call inputEvent [event bytes] 0
}

proc sneak { dir } {
    event variant ctrl [KeyDir value down]
    gui call inputEvent [event bytes] 0
    $dir
    event variant ctrl [KeyDir value up]
    gui call inputEvent [event bytes] 0
}

proc renderPeriodically { } {
    set result [gui call step [ticks]]
    if { $result == 1 } {
        after 100 renderPeriodically
    } else {
        gui call deinit
        global running
        set running 0
    }
}

renderPeriodically

vwait running
