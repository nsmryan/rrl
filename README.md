== Rust Roguelike, Zig Version ==

This repository contains an incomplete re-write of the [Rust Roguelike](https://github.com/nsmryan/RustRoguelike) project in Zig.

This is an attempt to rebuild the entire game logic and visuals.


== Some Zig/Rust Notes ==

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

Zig ability to get enum/union tags and to use an enum for union tags is much better then my experience
with Rust.

I do have memory use issues in Zig which I would not have in Rust. Mostly found by simple tests.
The main problems are pointers to memory that it realloced like ArrayList.

Zig standard library has a fixed array datastructure, which Rust does not have. Rust in general
led me to allocate a lot with a global allocator, while in Zig allocation is much more controlled.

The Rust version seems to create a number of threads which I did not spawn myself, which does not make
me feel like I control my codebase. The Zig does not do this.

Zig would allow a very controlled Map and Tile type - currently maps are a simple array, unlike Rust where
I have a vector of vectors, but that is not completely Rusts fault.
However, with packed structs a tile could be a u16, making the map quite manageable. This is not done
because of zigtcl not supporting bit offset pointers, and this data is not reflected in TypeInfo anyway
at the moment.


=== Next Steps ===

Get hammer working- need to wait a turn, and have a strong hit and make sure that this breaks walls into rubble.
May need to make sure grass and rubble are possible in the world, or add them.

AI

Level generation

Game as a sequence of levels

