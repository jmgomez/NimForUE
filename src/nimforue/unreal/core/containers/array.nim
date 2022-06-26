include ../../definitions
import std/[sugar]

type TArray*[T] {.importcpp: "TArray<'0>", bycopy } = object

proc num*[T](arr:TArray[T]): int32 {.importcpp: "#.Num()" noSideEffect}
proc remove*[T](arr:TArray[T], value:T) {.importcpp: "#.Remove(#)".}
proc removeAt*[T](arr:TArray[T], idx:int32) {.importcpp: "#.RemoveAt(#)".}
proc add*[T](arr:TArray[T], value:T) {.importcpp: "#.Add(#)".}

proc `[]`*[T](arr:TArray[T], i: int32): var T {. importcpp: "#[#]",  noSideEffect.}
proc `[]=`*[T](arr:TArray[T], i: int32, val : T)  {. importcpp: "#[#]=#",  }

# proc `[]`*[T](arr:TArray[T], i: int): var T {. inline, noSideEffect.} = arr[i.int32]

# proc `[]=`*[T](arr:TArray[T], i: int, val : T)  {. inline  .} = arr[i.int32] = val why this doesnt work like so?


proc makeTArray*[T](): TArray[T] {.importcpp: "'0(@)", constructor, nodecl.}
# proc makeTArray*[T](): TArray[T] {.importcpp: "'0(@)", constructor, nodecl.}

# proc makeTArray*[T](values:openarray[T]): TArray[T] {.importcpp: "'0({@})", constructor, nodecl.} #TODO

proc len*[T](arr:TArray[T]) : int {.inline.} = arr.num[T]().int

iterator items*[T](arr: TArray[T]): T =
  for i in 0..(arr.num()-1):
    yield arr[i.int32]

proc map*[T, U](xs:TArray[T], fn : T -> U) : TArray[U] = 
  var arr = makeTArray[U]() #TODO bind the capacity and set it here so it doesnt reallocate the size
  for x in xs:
    arr.add(fn(x))
  arr

proc filter*[T](xs:TArray[T], fn : T -> bool) : TArray[T] =
  var arr = makeTArray[T]()
  for x in xs:
    if fn(x):
      arr.add x
  arr

# iterator pairs*[T](arr: TArray[T]): tuple[key: int, val: T] =
#   for i in 0 .. <arr.len:
#     yield (i.int, arr[i])



