#!/usr/bin/env lua
require "ex"

print"os.chdir"
assert(os.chdir("tests"))
print(os.currentdir())

print"os.mkdir"
assert(os.mkdir("Foo.test"))
assert(os.chdir("Foo.test"))
