import uobject

type TSoftObjectPtr*[out T] {.importcpp:"TSoftObjectPtr<'0>", bycopy.} = object
type TSoftClassPtr*[out T] {.importcpp:"TSoftClassPtr<'0>", bycopy.} = object


proc makeTSoftObjectPtr*[T : UObject]() : TSoftObjectPtr[T] {.importcpp:"TSoftObjectPtr<'*0>()" constructor.}
proc makeTSoftObjectPtr*[T : UObject](obj : ptr T) : TSoftObjectPtr[T] {.importcpp:"TSoftObjectPtr<'*1>(#)" constructor.}

proc get*[T : UObject](softObj : TSoftObjectPtr[T]) : ptr T {.importcpp:"#.Get()".}



proc makeTSoftClassPtr*[T : UObject]() : TSoftClassPtr[T] {.importcpp:"TSoftClassPtr<'*0>()" constructor.}
proc makeTSoftClassPtr*[T : UObject](cls : UClassPtr) : TSoftClassPtr[T] {.importcpp:"TSoftClassPtr<'*0>(#)" constructor.}

proc get*[T : UObject](softClass : TSoftClassPtr[T]) : UClassPtr {.importcpp:"#.Get()".}



