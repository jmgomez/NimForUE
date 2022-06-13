import ../uobject

type TSubclassOf*[T]  {. importcpp: "TSubclassOf<'0>".} = object

converter toUClassPtr*(cont: TSubclassOf): UClassPtr {. importcpp: "#".}
converter toSubclass*[T : UObject ](t:T): TSubclassOf[T] {. importcpp: "UReflectionHelpers::ToSubclass<'*1>()".}
