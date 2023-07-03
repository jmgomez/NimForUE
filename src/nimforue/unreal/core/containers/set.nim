include ../../definitions
import array

type TSet*[T] {.importcpp.} = object

func num*[T](setparam:TSet[T]): int32 {.importcpp: "#.Num()" .}
func len*[T](setparam:TSet[T]): int32 {.importcpp: "#.Num()" .}
proc remove*[T](setparam:TSet[T], value:T) {.importcpp: "#.Remove(#)".}
proc add*[T](setparam:TSet[T], value:T) {.importcpp: "#.Add(#)".}
proc findOrAdd*[T](setparam:TSet[T], value:T) : T {.importcpp: "#.FindOrAdd(#)".}
func reserve*[T](setparam:TSet[T], value:int32) {.importcpp: "#.Reserve(#)".}

proc toArray*[T](setparam:TSet[T]) : TArray[T] {.importcpp: "#.Array()" .}
