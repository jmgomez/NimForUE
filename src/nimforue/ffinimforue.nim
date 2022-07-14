

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


proc createUEReflectedTypes() = 
    let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEBindings"))
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
#returns a pointer to a nimHotreload. The type is not passed because it's a type that exists in UE
#and host doesnt know anything about ue symbols

proc printAllClassAndProps*(prefix:string, package:UPackagePtr) =
    let classes = getAllObjectsFromPackage[UNimClassBase](package)

    UE_Error prefix & " len classes: " & $classes.len()
    for c in classes:
        UE_Warn " Class " & c.getName()
        for p in getFPropsFromUStruct(c):
            UE_Log "Prop " & p.getName()

proc onNimForUELoaded(n:int32) : pointer {.ffi:genFilePath} = 
    UE_Log(fmt "Nim loaded for {n} times")
  
    try:
        let pkg = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUEBindings"))
    

        # printAllClassAndProps("PRE", pkg)
        let nimHotReload = emitUStructsForPackage(pkg)
        
        

        # printAllClassAndProps("POST", pkg)

        # scratchpadEditor()
        return nimHotReload
    except Exception as e:
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()
    # scratchpadEditor()



#called right before it is unloaded
#called from the host library

#returns a TMap<UClassPtr, UClassPtr> with the classes that needs to be hotreloaded
proc onNimForUEUnloaded() : void {.ffi:genFilePath}  = 
    UE_Log("Nim for UE unloaded")
   

    discard
