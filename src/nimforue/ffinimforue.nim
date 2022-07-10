

include unreal/prelude
import typegen/[uemeta, ueemit]


import macros/[ffi, uebind]
import std/[times]
import strformat
import manualtests/manualtestsarray
#define on config.nims
const genFilePath* {.strdefine.} : string = ""

proc fromTheEditor() : void  {.ffi:genFilePath}  = 
    scratchpadEditor()

proc testCallUFuncOn(obj:pointer) : void  {.ffi:genFilePath}  = 
    let executor = cast[UObjectPtr](obj)
    testArrayEntryPoint(executor)
    # testVectorEntryPoint(executor)
    scratchpad(executor)



uStruct FMyNimStruct:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
        testField : int32
        testField2 : FString
        objProperty : UObjectPtr

    uprop(EditAnywhere, BlueprintReadOnly):
        amazing : float32
        vectorTest : FVector
        # arrayProp : TArray[int32]

uStruct FMyNimStruct2:
    (BlueprintType)
    uprop(EditAnywhere):
        testField : int32
        testField2 : FString
    uprop(OtherValues):
        param : FMyNimStruct
        param2 : FString

uClass UObjectDsl:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        testField : FString


proc createUEReflectedTypes() = 
    let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEDemo"))
    let clsFlags =  (CLASS_Inherit | CLASS_ScriptInherit )
    let className = "UNimClassWhateverProp"
    let ueVarType = makeUEClass(className, "UObject", clsFlags,
                    @[
                        makeFieldAsUProp("TestField", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("TestInt", "int32", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("TestInt2", "float", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("AnotherField", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                    ])

#    for cls in getAllObjectsFromPackage[UClass](package):
#     if cls.getName().equals(className):
#         cls.BeginDestroy()


    let newCls = ueVarType.toUClass(package)
    UE_Log "Class created! " & newCls.getName()


#function called right after the dyn lib is load
#when n == 0 means it's the first time. So first editor load
#called from C++ NimForUE Module
proc onNimForUELoaded(n:int32) : void {.ffi:genFilePath} = 
    # return
    UE_Log(fmt "Nim loaded for {n} times")
    # #TODO take a look at FFieldCompiledInInfo for precomps
    # if n == 0:
    createUEReflectedTypes()
    try:
        let pkg = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEDemo"))
        emitUStructsForPackage(pkg)

    except Exception as e:
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()
    # scratchpadEditor()



#called right before it is unloaded
#called from the host library
proc onNimForUEUnloaded() : void {.ffi:genFilePath}  = 
    # destroyAllUStructs()
    UE_Log("Nim for UE unloaded")

    # for structEmmitter in ueEmitter.uStructsEmitters:
    # let scriptStruct = structEmmitter(package)

    discard
