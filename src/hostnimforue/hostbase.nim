import std/[locks, dynlib]
var libLock* : Lock
var lib* : LibHandle