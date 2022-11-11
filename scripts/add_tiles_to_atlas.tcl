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
    set x_offset [expr $dim * ($key % 16)]
    set y_offset [expr $dim * ($key / 16)]
    dict set sprites $value [list [expr $x + $x_offset] [expr $y + $y_offset] $dim $dim]
}

close $spriteFile
set finalAtlas [open $spriteAtlasName w]
dict for { key value } $sprites {
    puts $finalAtlas [concat $key $value]
}
