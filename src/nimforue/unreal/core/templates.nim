

type
  ESPMode* {. importcpp, nodecl, size:sizeof(uint8).} = enum
    NoThreadSafe, ThreadSafe

  #Notice uses ThraedSafe in the cpp side of things
  TSharedRef*[T] {.importcpp.} = object 
    mode* {.importcpp: "Mode".} : ESPMode 
  TSharedPtr*[T] {.importcpp.} = object 
    mode* {.importcpp: "Mode".} : ESPMode




# func makeShared*[T](): TSharedRef[T] {.importcpp: "MakeShared<'*0>()".}
func makeShared*[T](): TSharedPtr[T] {.importcpp: "MakeShared<'*0>()".}
func makeShared*[T](pointr : ptr T) : TSharedPtr[T] {.importcpp: "TSharedPtr<'*0>(#)", constructor.}


func get*[T](sharedPtr : TSharedPtr[T]) : ptr T {.importcpp: "#.Get()".}