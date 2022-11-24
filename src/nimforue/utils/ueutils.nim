import ../unreal/coreuobject/[uobject, nametypes]
import ../unreal/core/containers/[unrealstring, map, array]
import ../typegen/models

import std/[options, strutils, tables, sequtils, sugar, strscans]
import utils

const DelegateFuncSuffix* = "__DelegateSignature"
const DelegateFuncSuffixLength* = DelegateFuncSuffix.len()
#utils specifics to unreal used accross the project

func isGeneric*(str: string): bool = "[" in str and "]" in str
func appendCloseGenIfOpen*(str: string) : string =
  if "[" in str and "]" notin str: str & "]"
  else: str
#use multireplace
proc extractTypeFromGenericInNimFormat*(str :string, genericType : static string="") : string = 
    if genericType=="":
        var generic, inner : string
        if scanf(str, "$*[$*]", generic, inner): appendCloseGenIfOpen(inner)
        else: str
    else:
        var inner : string
        if scanf(str, genericType&"[$*]", inner): appendCloseGenIfOpen(inner)
        else: str


proc extractOuterGenericInNimFormat*(str :string) : string = 
    var generic, inner : string
    if scanf(str, "$*[$*]", generic, inner): generic
    else: str

proc extractTypeFromGenericInNimFormat*(str, outerGeneric, innerGeneric :string) : string = 
    str.replace(outerGeneric, "").replace(innerGeneric, "").replace("[").replace("]", "")

func getInnerCppGenericType*(cppType:string) : string = 
    var generic, inner : string
    if scanf(cppType, "$*<$*>", generic, inner): inner
    else: cppType

func getNameOfUENamespacedEnum*(namespacedEnum:string) : string = namespacedEnum.replace("::Type", "")

proc extractKeyValueFromMapProp*(str:string) : seq[string] = 
    var key, value : string
    if scanf(str, "TMap[$*, $*]", key, value): 
        @[appendCloseGenIfOpen(key), appendCloseGenIfOpen(value)]
    else: @[]



proc removeLastLettersIfPtr*(str:string) : string = 
    if str.endsWith("Ptr"): str.substr(0, str.len()-4) else: str

proc addPtrToUObjectIfNotPresentAlready*(str:string) : string = 
    if str.endsWith("Ptr"): str else: str & "Ptr"

func tryUECast*[T : UObject](obj:UObjectPtr) : Option[ptr T] = someNil ueCast[T](obj)
    
func ueMetaToNueMeta*(ueMeta : TMap[FName, FString]) : seq[UEMetadata] = 
    var meta = newSeq[UEMetadata]()
    for key in ueMeta.keys():
        meta.add(makeUEMetadata($key, $ueMeta[key]))
    meta
        


# func As*[T : UStruct](field:UFieldPtr) : ptr T =  tryUECast[T](field).getOrRaise("Field is not a struct")