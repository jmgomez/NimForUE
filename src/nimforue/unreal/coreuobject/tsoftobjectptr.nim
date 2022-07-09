import uobject

type TSoftObjectPtr*[out T] {.importcpp:"TSoftObjectPtr<'0>", bycopy.} = object
type TSoftClassPtr*[out T] {.importcpp:"TSoftClassPtr<'0>", bycopy.} = object


proc makeTSoftObject*[T : UObject]() : TSoftObjectPtr[T] {.importcpp:"TSoftObjectPtr<'*0>()" constructor.}


proc makeTSoftObject*[T : UObject](obj : ptr T) : TSoftObjectPtr[T] {.importcpp:"TSoftObjectPtr<'*1>(#)" constructor.}

proc get*[T : UObject](softObj : TSoftObjectPtr[T]) : ptr T {.importcpp:"#.Get()".}



