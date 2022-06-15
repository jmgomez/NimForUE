
import ../core/containers/unrealstring

type FName* {. importcpp .} = object


proc makeFName*(str : FString) : FName {. importcpp: "FName(#)".}

proc toFString*(name : FName) : FString {. importcpp: "#.ToString()".}