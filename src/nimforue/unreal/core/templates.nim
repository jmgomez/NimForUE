import ../coreuobject/coreuobject

type
  ESPMode* {. importcpp, nodecl, size:sizeof(uint8).} = enum
    NoThreadSafe, ThreadSafe

  #Notice uses ThraedSafe in the cpp side of things
  TSharedRef*[out T] {.importcpp .} = object 
    mode* {.importcpp: "Mode".} : ESPMode 
  TSharedPtr*[out T] {.importcpp.} = object 
    mode* {.importcpp: "Mode".} : ESPMode

  TWeakObjectPtr*[out T] {.importcpp.} = object
  TWeakPtr*[out T] {.importcpp.} = object

  TSmartPtr[T] = TSharedPtr[T] | TSharedRef[T] | TWeakObjectPtr[T] | TWeakPtr[T]
  TShared[T] = TSharedPtr[T] | TSharedRef[T]

func makeSharedWeak*[T](v: TSharedPtr[T]): TWeakPtr[T] {.importcpp: "'0(#)".}
func makeSharedRef*[T](): TSharedRef[T] {.importcpp: "MakeShared<'*0>()".}
func makeSharedPtr*[T](): TSharedPtr[T] {.importcpp: "MakeShared<'*0>()".}
func makeSharedPtr*[T](pointr : ptr T) : TSharedPtr[T] {.importcpp: "TSharedPtr<'*0>(#)", constructor.}
func makeSharedRef*[T](pointr : ptr T) : TSharedRef[T] {.importcpp: "TSharedRef<'*0>(#)", constructor.}

func sharedThisWeak*[T](v: ptr T): TWeakPtr[T] {.importcpp: "SharedThis(#)".}
func sharedThisRef*[T](v: ptr T): TSharedRef[T] {.importcpp: "SharedThis(#)".}

func get*[T](sharedPtr : TShared[T] | TWeakObjectPtr[T]) : ptr T {.importcpp: "#.Get()".}
func pin*[T](weakPtr :TWeakPtr[T]) : TSharedPtr[T] {.importcpp: "#.Pin()".}
func isValid*[T](sharedPtr : TSmartPtr[T]) : bool {.importcpp: "#.IsValid()".}

func toSharedRef*[T](sharedPtr : TSharedPtr[T]) : TSharedRef[T] {.importcpp: "#.ToSharedRef()".}
func toSharedPtr*[T](sharedRef : TSharedRef[T]) : TSharedPtr[T] {.importcpp: "#.ToSharedPtr()".}
func toWeakPtr*[T](shared: TShared[T]): TWeakPtr[T] {.importcpp: "#.ToWeakPtr()".}