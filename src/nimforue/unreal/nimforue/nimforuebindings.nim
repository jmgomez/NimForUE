import ../coreuobject/[uobject, unrealtype]
import ../core/containers/unrealstring 
import std/[typetraits, strutils]
include ../definitions


type 
    UFunctionCaller* {.importc, inheritable, pure .} = object

    
# proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:openarray[pointer]) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc invoke*(functionCaller: UFunctionCaller, executor:ptr UObject, returnResult:pointer) : void {.importcpp: "#.Invoke(@)".}

proc callUFuncOn*(executor:UObjectPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}
proc callUFuncOn*(class:UClassPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}



proc UE_Log*(msg: FString) : void {.importcpp: "UFunctionCaller::NimForUELog(@)".}


proc getPropertyValuePtr*[T](property:FPropertyPtr, container : pointer) : ptr T {.importcpp: "GetPropertyValuePtr<'*0>(@)", header:"UPropertyCaller.h".}
proc setPropertyValuePtr*[T](property:FPropertyPtr, container : pointer, value : ptr T) : void {.importcpp: "SetPropertyValuePtr<'*3>(@)", header:"UPropertyCaller.h".}


type 
    FNimTestBase* {.importcpp, inheritable, pure.} = object
        ActualTest* : proc (test:var FNimTestBase) : void {.cdecl.}


proc makeFNimTestBase*(testName:FString): FNimTestBase {.importcpp:"FNimTestBase(#)", constructor.}
proc reloadTest*(test:FNimTestBase):void {.importcpp:"#.ReloadTest()".}
proc testTrue*(test:FNimTestBase, msg:FString, value:bool):void {.importcpp:"#.TestTrue(@)".}


proc getFPropertyByName*(class:UStructPtr, propName:var FString) : FPropertyPtr {.importcpp: "UReflectionHelpers::GetFPropetyByName(@)"}

proc getUTypeByName*[T :UStruct](typeName:FString) : ptr T {.importcpp:"UReflectionHelpers::GetUTypeByName<'*0>(@)".}


proc newObjectFromClass*(className:UClassPtr) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}



proc getClassByName*(className:FString) : UClassPtr = getUTypeByName[UClass](className)
proc getScriptStructByName*(structName:FString) : UScriptStructPtr = getUTypeByName[UScriptStruct](structName)
proc getUStructByName*(structName:FString) : UStructPtr = getUTypeByName[UStruct](structName)

proc newUObject*[T:UObject]() : ptr T = 
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cast[ptr T](newObjectFromClass(cls)) 





