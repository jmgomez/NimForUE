include ../../definitions
import array

type TSet*[out T] {.importcpp.} = object

func num*[T](s:TSet[T]): int32 {.importcpp: "#.Num()" .}
func len*[T](s:TSet[T]): int32 {.importcpp: "#.Num()" .}
func remove*[T](s:TSet[T], element:T) {.importcpp: "#.Remove(#)".}
func add*[T](s:TSet[T], element:T) {.importcpp: "#.Add(#)".}
func findOrAdd*[T](s:TSet[T], element:T) : T {.importcpp: "#.FindOrAdd(#)".}
func reserve*[T](s:TSet[T], element:int32) {.importcpp: "#.Reserve(#)".}
func toTArray*[T](s:TSet[T]) : TArray[T] {.importcpp: "#.Array()" .}
func contains*[T](s:TSet[T], element: T): bool {.importcpp: "#.Contains(#)"}

func makeTSet*[T](): TSet[T] {.importcpp: "'0()", constructor .}
func makeTSet*[T](args:TArray[T]): TSet[T] {.importcpp: "'0(#)", constructor .}
func makeTSet*[T](a:T, args:varargs[T]): TSet[T] = 
  result = makeTSet[T]()
  result.reserve((args.len()+1).int32)
  result.add(a)
  for a in args:
    result.add a

iterator items*[T](s: TSet[T]): T =
  #TODO bind the Iterator instead. 
  let arr = s.toTArray()  
  for i in 0..(arr.num()-1):
    yield arr[i.int32]
