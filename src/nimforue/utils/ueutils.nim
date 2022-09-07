import ../unreal/coreuobject/[uobject]
import std/[options, strutils, sequtils, sugar]
import utils

const DelegateFuncSuffix* = "__DelegateSignature"
#utils specifics to unreal used accross the project

#use multireplace
proc extractTypeFromGenericInNimFormat*(str, genericType :string) : string = 
    str.replace(genericType, "").replace("[").replace("]", "")

proc extractTypeFromGenericInNimFormat*(str, outerGeneric, innerGeneric :string) : string = 
    str.replace(outerGeneric, "").replace(innerGeneric, "").replace("[").replace("]", "")

proc extractKeyValueFromMapProp*(str:string) : seq[string] = 
    str.extractTypeFromGenericInNimFormat("TMap").split(",")
       .map(s=>strip(s))

proc removeLastLettersIfPtr*(str:string) : string = 
    if str.endsWith("Ptr"): str.substr(0, str.len()-4) else: str

proc addPtrToUObjectIfNotPresentAlready*(str:string) : string = 
    if str.endsWith("Ptr"): str else: str & "Ptr"

func tryUECast*[T : UObject](obj:UObjectPtr) : Option[ptr T] = someNil ueCast[T](obj)
    


# func As*[T : UStruct](field:UFieldPtr) : ptr T =  tryUECast[T](field).getOrRaise("Field is not a struct")