== Notes ==

This repository is part of an exploration of Zig that I am doing, along with a number of my other repositories.

Eventually there might be something here, if things go well.


=== Utilties ===

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

roguelike_utils and roguelike_map are ported.

Some very basic entity concepts are ported.

Zig and TCL can draw using draw commands.

Next steps:

  * TCL draw map based on tile contents.
  * Add enough to entities to create the player and some golems.
  * TCL draw these entities.
  * Start to build up basics of each game architecture concept
    * Game structure
    * Messaging
    * Configuration
    * Input processing
    * Actions for state transitions
    * Game step
    * Message resolution
  * Once the vertical structure is in place, build outwards by adding features.
