
import ../core/containers/unrealstring

include ../definitions



type 
    FName* {. importcpp .} = object
    EName* {. importcpp, size:sizeof(uint32).} = enum
        ENone = 0
        



proc makeFName*(str : FString) : FName {. importcpp: "FName(#) " constructor.}
proc makeFName(name : EName) : FName {. importcpp: "FName(#) " constructor.}

proc n*(str:FString) : FName {. inline .} = makeFName(str)

proc toFString*(name : FName) : FString {. importcpp: "#.ToString()".}

converter ENameToFName*(ename:EName) : FName = makeFName ename       

