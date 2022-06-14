import ../uobject


type TSubclassOf*[out T : UObject]  {. importcpp: "TSubclassOf<'0>".} = object

proc makeTSubclassOf*[T : UObject]() : TSubclassOf[T] {. importcpp: "TSubclassOf<'0>()" constructor.}
proc makeTSubclassOf*[T : UObject](cls:UClassPtr) : TSubclassOf[T] {. importcpp: "TSubclassOf<'0>(#)" constructor.}

proc get*(softObj : TSubclassOf) : UClassPtr {.importcpp:"#.Get()".}

# proc toUClassPtr*[T : UObject](cont: TSubclassOf[T]): UClassPtr {. importcpp: "UReflectionHelpers::FromSubclass<'*0>(@)".}
# proc toSubclass*[T : UObject ]( cls:UClassPtr ): TSubclassOf[T] {. importcpp: "UReflectionHelpers::ToSubclass<'*0>()".}

# converter fromUClass[T:UObject](cls:UClassPtr) : TSubclassOf[T] = makeTSubclassOf[T](cls)
#There is a converter in nimforuebindings
