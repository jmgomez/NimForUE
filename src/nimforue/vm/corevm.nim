import vmtypes

proc castIntToPtr*[T](address:int) : ptr T = nil
proc toText*(str:string): FText = FText(str)
proc toFString*(text:FText): FString = FString(text)
