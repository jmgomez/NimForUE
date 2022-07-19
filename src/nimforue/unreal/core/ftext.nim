include ../definitions
import containers/unrealstring
import ../coreuobject/nametypes
 
type FText* {. importcpp, header: ueIncludes, bycopy.} = object 

proc fromFString*(str: FString) : FText {. importcpp:"FText::FromString(#)".}
proc fromFName*(str: FName) : FText {. importcpp:"FText::FromName(#)".}
proc toFString*(text:FText) : FString {. importcpp:"#.ToString()".}
