lassign $::argv spriteAtlasName tileLocationsName

set spriteFile [open $spriteAtlasName r]
set tileLocationsFile [open $tileLocationsName r]

set spriteLines [split [string trim [read $spriteFile]] "\n"]
set tileLocations [read $tileLocationsFile]

foreach line $spriteLines {
    dict set sprites [lindex $line 0] [lrange $line 1 end]
}
lassign [dict get $sprites rustrogueliketiles] x y width height

set dim 16
dict for {key value} $tileLocations {
    # Keys are 1 indexed, so move back to 0.
    set key [expr $key - 1]
    set x_offset [expr $dim * ($key % 16)]
    set y_offset [expr $dim * ($key / 16)]
    set new_x [expr $x + $x_offset]
    set new_y [expr $y + $y_offset]
    dict set sprites $value [list $new_x $new_y $dim $dim]
}

close $spriteFile
set finalAtlas [open $spriteAtlasName w]
dict for { key value } $sprites {
    puts $finalAtlas [concat $key $value]
}
