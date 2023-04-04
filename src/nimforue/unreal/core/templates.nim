

type
  ESPMode* {. importcpp, nodecl, size:sizeof(uint8).} = enum
    NoThreadSafe, ThreadSafe

  #Notice uses ThraedSafe in the cpp side of things
  TSharedRef*[T] {.importcpp.} = object 
    mode* {.importcpp: "Mode".} : ESPMode 




func makeShared*[T](): TSharedRef[T] {.importcpp: "MakeShared<'*0>()".}