== Notes ==

I am finding that Zig encourages me to test each and every function as I write it.
This seems like a combination of:

  * Zig's newness to me- I'm never sure that I will actually get things correct.
  * Zig's easy error handling. I feel like I can get tests written, and I have a somewhat similar feeling of error paths to Rust and Haskell.
  * Zig does not evaluate code that is not used, which seems like a minefield to me. However, if you test a bit you at least shake out the main issues.


I like the explicitness of allocators. I end up duplicating a lot of code for tests, but in the end
I'm glad to be able to handle allocation like this.

This feels like it gives me a lot more control then Rust's temptation to use the global allocator,
or C's constant cliff of whether I really need to allocate or just keep fixed size buffers.


Ran into some compiler bugs when testing. Also the fact that numeric literals have a comptime_int type
results in some verbosity, although its not such a big deal.


Iterator is much simpler and smaller. There is weirdness to it, like the whole generics-are-functions thing,
but its not nearly as baroque as Rust as it does not use lifetime parameters.


My Zig ended up being more lines for Comp because of all the unit tests. Without them it was a little smaller.


One concern in Haskell and Rust is always using the correct derives, especially with Rust's
orphan rule.

In Zig so far this is mostly about comptime- std.meta.eql gives equality for basic types at least,
and formatting appears to be able to print these types as well.

How this will work for TCL style printing and parsing I do not yet know. Also, if you want to
implement equality specially for a type, you simply implement your own function (perhaps there
is a standard way to do this or an interface for it?) and user's have to know to use this instead
of comptime eql. However, this is in line with the Zig no-hidden-control-flow concept.


Zig does not restrict floats the same. It also provides clamp, which I did in Rust.
Also I believe I will be able to use Zig's random numebr generation, which I couldn't in Rust
due to orphan rule serde support.


=== Progress ===

The roguelike_utils crate seems like it is basically ported to Zig. Perlin noise is no longer
used, and random numbers might just come from the std library.

Could do SDL2 next, maybe draw command executable. 
Might also try roguelike_map to build upwards.

