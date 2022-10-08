load zig-out/lib/librrl.so

package require rrl

puts "Starting RRL"

rrl::Pos create p
p set x 1
p set y 2

puts "x = [p get x]"
puts "y = [p get y]"

rrl::Map create m
# This call needs an allocator!
#m fromBytes [rrl::Map call fromDims 3 3 [allocator]]

puts "map created"
