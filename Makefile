
.PHONY: rebuild retest run build test atlas sloc

run:
	zig build run

build:
	zig build

test: 
	zig build test

rebuild:
	find src/* -name "*.zig" | entr -c zig build

retest:
	find src/* -name "*.zig" | entr -c zig build test

atlas:
	zig build atlas

sloc: 
	cloc src/*/*.zig
