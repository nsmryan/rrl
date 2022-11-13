#!/usr/bin/tclsh
load zig-out/lib/librrl.so
package require rrl
namespace import rrl::*


proc pos { x y } {
    return [Pos call init $x $y]
}

set playerId 0

Gui create gui
gui setBytes [Gui call init 0 $zigtcl::tclAllocator]

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
    set result [gui call step]
    if { $result == 1 } {
        gui call draw
        after 100 renderPeriodically
    } else {
        gui call deinit
        global running
        set running 0
    }
}

renderPeriodically

vwait running
