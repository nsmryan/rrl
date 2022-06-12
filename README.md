

== Notes

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
