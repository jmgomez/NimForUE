when defined(nuevm):
    import vmtypes
else:
    import ../unreal/coreuobject/[uobject, nametypes, coreuobject]
    import ../unreal/core/containers/[unrealstring, map, array]
    import ../unreal/core/math/vector

import ../codegen/models

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

proc extractInnerGenericInNimFormat*(str :string) : string =
    var generic, inner : string
    if scanf(str, "$*[$*]", generic, inner): inner.appendCloseGenIfOpen()
    else: str

func applyFunctionToInnerGeneric*(str :string, fun : proc (str:string) : string {.gcsafe.} ) : string =
    {.cast(noSideEffect).}:
        var generic, inner : string
        if scanf(str, "$*[$*]", generic, inner): generic & "[" & fun(inner) & "]"
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

when not defined(nuevm): #TODO expose this somehow?
    func tryUECast*[T : UObject](obj:UObjectPtr) : Option[ptr T] = 
        if obj.isNil: none[ptr T]()
        else: someNil(ueCast[T](obj))

    func tryCastField*[T : FProperty](prop:FPropertyPtr) : Option[ptr T] = someNil castField[T](prop)
    
func ueMetaToNueMeta*(ueMeta : TMap[FName, FString]) : seq[UEMetadata] = 
    var meta = newSeq[UEMetadata]()
    for key in ueMeta.keys():
        meta.add(makeUEMetadata($key, $ueMeta[key]))
    meta
        

#"FLinearColor": "(R=1.000000,G=1.000000,B=1.000000,A=1.000000)"
func makeFLinearColor*(colorStr:string) : FLinearColor = 
    var r, g, b, a : float
    if scanf(colorStr, "(R=$f,G=$f,B=$f,A=$f)", r, g, b, a): FLinearColor(r:r, g:g, b:b, a:a)
    else: FLinearColor(r:0.0, g:0.0, b:0.0, a:0.0)
#FVector2D (X=1.000,Y=1.000)
func makeFVector2D*(vecStr:string) : FVector2D = 
    var x, y : float
    if scanf(vecStr, "(X=$f,Y=$f)", x, y): FVector2D(x:x, y:y)
    else: FVector2D(x:0.0, y:0.0)
#FVector 1.000000,1.000000,1.000000
func makeFVector*(vecStr:string) : FVector = 
    var x, y, z : float
    if scanf(vecStr, "$f,$f,$f", x, y, z): FVector(x:x, y:y, z:z)
    else: FVector(x:0.0, y:0.0, z:0.0)

#FRotator 4.000000,2.000000,1.000000
func makeFRotator*(rotStr:string) : FRotator = 
    var pitch, yaw, roll : float
    if scanf(rotStr, "$f,$f,$f", roll, yaw, pitch): FRotator(pitch:pitch, yaw:yaw, roll:roll)
    else: FRotator(pitch:0.0, yaw:0.0, roll:0.0)