import ../coreuobject/coreuobject

type
  ESPMode* {. importcpp, nodecl, size:sizeof(uint8).} = enum
    NoThreadSafe, ThreadSafe

  #Notice uses ThraedSafe in the cpp side of things
  TSharedRef*[out T] {.importcpp .} = object 
    mode* {.importcpp: "Mode".} : ESPMode 
  TSharedPtr*[out T] {.importcpp.} = object 
    mode* {.importcpp: "Mode".} : ESPMode

  TWeakObjectPtr*[T] {.importcpp.} = object

  TSmartPtr[T] = TSharedPtr[T] | TSharedRef[T] | TWeakObjectPtr[T]



func makeSharedRef*[T](): TSharedRef[T] {.importcpp: "MakeShared<'*0>()".}
func makeShared*[T](): TSharedPtr[T] {.importcpp: "MakeShared<'*0>()".}
func makeShared*[T](pointr : ptr T) : TSharedPtr[T] {.importcpp: "TSharedPtr<'*0>(#)", constructor.}
func makeSharedRef*[T](pointr : ptr T) : TSharedRef[T] {.importcpp: "TSharedRef<'*0>(#)", constructor.}


func get*[T](sharedPtr : TSmartPtr[T]) : ptr T {.importcpp: "#.Get()".}
func isValid*[T](sharedPtr : TSmartPtr[T]) : bool {.importcpp: "#.IsValid()".}

func toSharedRef*[T](sharedPtr : TSharedPtr[T]) : TSharedRef[T] {.importcpp: "#.ToSharedRef()".}
func toSharedPtr*[T](sharedRef : TSharedRef[T]) : TSharedPtr[T] {.importcpp: "#.ToSharedPtr()".}


# {.experimental: "dotOperators".}

# proc `.`*[T](sharedPtr : TSmartPtr[T]) : ptr T {.importcpp: "#->".}