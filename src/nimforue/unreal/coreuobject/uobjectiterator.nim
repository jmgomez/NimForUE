import uobject

type TObjectIterator*[T] {.importcpp .} = object


proc makeTObjectIterator*[T](): TObjectIterator[T] {. importcpp:"'0()", constructor .}
proc next*[T](it:var TObjectIterator[T]) : void {. importcpp:"(++#)" .} 
proc isValid[T](it: TObjectIterator[T]): bool {.importcpp: "((bool)(#))", noSideEffect.}
proc get*[T](it:TObjectIterator[T]) : ptr T {. importcpp:"*#" .} 

iterator items*[T](it:var TObjectIterator[T]) : var TObjectIterator[T] =
  while it.isValid():
    yield it
    it.next()