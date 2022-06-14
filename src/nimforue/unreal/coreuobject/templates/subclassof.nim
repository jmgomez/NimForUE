import ../uobject


type TSubclassOf*[out T : UObject]  {. importcpp: "TSubclassOf<'0>".} = object

proc makeTSubclassOf*[T : UObject]() : TSubclassOf[T] {. importcpp: "TSubclassOf<'*0>()" constructor.}
proc makeTSubclassOf*[T : UObject](cls:UClassPtr) : TSubclassOf[T] {. importcpp: "TSubclassOf<'*0>(#)" constructor.}

proc get*(softObj : TSubclassOf) : UClassPtr {.importcpp:"#.Get()".}

