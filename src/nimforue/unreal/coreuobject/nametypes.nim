
import ../core/containers/unrealstring

type FName* {. importcpp .} = object


proc makeFName*(str : FString) : FName {. importcpp: "FName(#) " constructor.}

proc n*(str:FString) : FName {. inline .} = makeFName(str)

proc toFString*(name : FName) : FString {. importcpp: "#.ToString()".}