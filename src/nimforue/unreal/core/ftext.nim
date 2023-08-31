include ../definitions
import containers/unrealstring
import ../coreuobject/nametypes
 
type FText* {. importcpp, bycopy.} = object 

proc fromFString*(str: FString) : FText {. importcpp:"FText::FromString(#)".}
proc fromFName*(str: FName) : FText {. importcpp:"FText::FromName(#)".}
proc toFString*(text:FText) : FString {. importcpp:"#.ToString()", ureflect.}
proc textToFString*(text:FText) : FString {. importcpp:"#.ToString()", ureflect.}

proc toText*(n: SomeNumber): FText {. importcpp:"FText::AsNumber(#)", ureflect .}
proc toText*(str: FString) : FText {. importcpp:"FText::FromString(#)", ureflect .}
proc toText*(str: string) : FText  = makeFString(str).toText()

proc `$`*(text: FText): string = $text.toFString()