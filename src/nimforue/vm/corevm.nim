import vmtypes
proc castIntToPtr*[T](address:int) : ptr T = nil
proc toText*(str:string): FText = FText(str)
proc textToFString*(text:FText): FString = FString(text)
proc toFString*(text:FText): FString = FString(text)

proc makeFName*(str:string): FName = default(FName)
proc nameFromInt*(n:int): FName = FName(n)
proc nameToFString*(name:FName): FString = default(FString)
proc toFString*(name:FName): FString = nameToFString(name)
proc `$`*(name:FName): string = name.nameToFString()

proc `==`*(a, b: FName): bool {.borrow.}
proc `==`*(a, b: FText): bool {.borrow.}


