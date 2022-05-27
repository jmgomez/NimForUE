import std/[locks, dynlib]
var libLock* : Lock
initLock(libLock)
var lib* : LibHandle