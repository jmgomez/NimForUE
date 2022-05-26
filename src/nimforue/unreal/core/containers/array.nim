

{.push header:"Containers/Array.h" .}

type TArray*[T] {.importcpp: "TArray<'0>", bycopy } = object

proc num*[T](arr:TArray[T]): int32 {.importcpp: "#.Num()" noSideEffect}
proc add*[T](arr:TArray[T], value:T) {.importcpp: "#.Add(#)".}

proc `[]`*[T](arr:TArray[T], i: int32): var T {. importcpp: "#[#]",  noSideEffect.}
proc `[]=`*[T](arr:TArray[T], i: int32, val : T)  {. importcpp: "#[#]=#",  noSideEffect.}


{.pop.}

proc makeTArray*[T](): TArray[T] {.importcpp: "'0(@)", constructor, nodecl.}

# proc makeTArray*[T](values:openarray[T]): TArray[T] {.importcpp: "'0({@})", constructor, nodecl.} #TODO

proc len*[T](arr:TArray[T]) : int32 {.inline.} = arr.num[T]()


iterator items*[T](arr: TArray[T]): T =
  for i in 0..(arr.num()-1).int:
    yield arr[i.int32]



# iterator pairs*[T](arr: TArray[T]): tuple[key: int, val: T] =
#   for i in 0 .. <arr.len:
#     yield (i.int, arr[i])



