load zig-out/lib/librrl.so

package require rrl

puts "Starting RRL"

rrl::Pos create p
p set x 1
p set y 2

puts "x = [p get x]"
puts "y = [p get y]"

rrl::Map create m
m setBytes [rrl::Map call fromDims 3 3 $zigtcl::tclAllocator]
#rrl::Pos create p
#p = [rrl::Pos call init 0 1]

puts "m width [m get width]"
puts "m height [m get height]"

rrl::Tile create t
t setBytes [rrl::Tile call shortDownWall]
rrl::Wall create w

#t setBytes [m call get [p bytes]]
w setBytes [t get down]

puts "pos info [rrl::Height name [w get height]] [rrl::Material name [w get material]]"

puts "map created"

rrl::Display create disp
disp setBytes [rrl::Display call init 800 600]

disp call push [rrl::DrawCmd call text "hello, tcl drawing!" [rrl::Pos call init 10 10] [rrl::Color call white] 1.0]
disp call present
after 1000


