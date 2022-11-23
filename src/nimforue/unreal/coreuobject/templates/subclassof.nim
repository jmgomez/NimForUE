import ../uobject


type TSubclassOf*[out T]  {. importcpp: "TSubclassOf<'0>".} = object

proc makeTSubclassOf*[T : UClass]() : TSubclassOf[T] {. importcpp: "TSubclassOf<'*0>()" constructor.}
proc makeTSubclassOf*[T : UClass](cls:UClassPtr) : TSubclassOf[T] {. importcpp: "TSubclassOf<'*0>(#)" constructor.}

proc get*(softObj : TSubclassOf) : UClassPtr {.importcpp:"#.Get()".}




