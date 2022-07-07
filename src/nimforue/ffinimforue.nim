

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




const ueStructType = UEType(name: "FMyNimStruct", kind: uStruct, fields: 
                            @[
                                makeFieldAsUProp("TestField2321", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                                makeFieldAsUProp("TestField2", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                                makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                            ])

const ueStructType2 = UEType(name: "FMyNimStruct2", kind: uStruct, fields: 
                            @[
                                makeFieldAsUProp("TestField2321", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                                makeFieldAsUProp("TestField2", "int32", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                            ])



emitType(ueStructType, ueStructType)
emitType(ueStructType2, ueStructType2)  



UStruct FMyNimStructMacro:
    (BlueprintType)
    uprop(EditAnywhere):
        testField : int32
        testField2 : FString
    uprop(OtherValues):
        param3 : int32
        param4 : FString
        param5 : int32
        param7 : FString



proc createUEReflectedTypes() = 
    let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEDemo"))
    let clsFlags =  (CLASS_Inherit | CLASS_ScriptInherit )
    let className = "UNimClassWhateverProp"
    let ueVarType = makeUEClass(className, "UObject", clsFlags,
                    @[
                        makeFieldAsUProp("TestField", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        makeFieldAsUProp("TestInt", "int32", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                    ])
    let newCls = ueVarType.toUClass(package)
    UE_Log "Class created! " & newCls.getName()

    
    



#function called right after the dyn lib is load
#when n == 0 means it's the first time. So first editor load
#called from C++ NimForUE Module
proc onNimForUELoaded(n:int32) : void {.ffi:genFilePath} = 
    UE_Log(fmt "Nim loaded for {n} times")
    # #TODO take a look at FFieldCompiledInInfo for precomps
    if n == 0:
        createUEReflectedTypes()

    let pkg = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEDemo"))
    genUStructsForPackage(pkg)

    scratchpadEditor()



#called right before it is unloaded
#called from the host library
proc onNimForUEUnloaded() : void {.ffi:genFilePath}  = 
    # destroyAllUStructs()
    UE_Log("Nim for UE unloaded")

    # for structEmmitter in ueEmitter.uStructsEmitters:
    # let scriptStruct = structEmmitter(package)

    discard
