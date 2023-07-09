import vmtypes

proc castIntToPtr*[T](address:int) : ptr T = nil
proc toText*(str:string): FText = FText(str)
proc toFString*(text:FText): FString = FString(text)

proc makeFName*(str:string): FName = default(FName)
proc nameFromInt*(n:int): FName = FName(n)
proc toFString*(name:FName): FString = default(FString)
proc `$`*(name:FName): string = name.toFString()

proc `==`*(a, b: FName): bool {.borrow.}
proc `==`*(a, b: FText): bool {.borrow.}


