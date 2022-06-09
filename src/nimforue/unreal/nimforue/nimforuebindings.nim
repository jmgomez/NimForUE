import ../coreuobject/[uobject, unrealtype]
import ../core/containers/unrealstring 
import std/[typetraits, strutils]

{.emit: """/*INCLUDESECTION*/
#define WITH_AUTOMATION_TESTS 1
#define WITH_DEV_AUTOMATION_TESTS 1
#define WITH_AUTOMATION_WORKER 1

#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "CoreMinimal.h"

#include  "Misc/AutomationTest.h"

""".}

{.push header: "UFunctionCaller.h"}

type 
    UFunctionCaller* {.importc, inheritable, pure, header:  "UFunctionCaller.h".} = object

    
# proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:openarray[pointer]) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc invoke*(functionCaller: UFunctionCaller, executor:ptr UObject, returnResult:pointer) : void {.importcpp: "#.Invoke(@)".}

proc callUFuncOn*(executor:UObjectPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}
proc callUFuncOn*(class:UClassPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}



proc UE_Log*(msg: FString) : void {.importcpp: "UFunctionCaller::NimForUELog(@)".}
# proc UE_Log*(msg: var FString) : void {.importcpp: "HelpersBindings::NimForUELog(@)" header: "HelpersBindings.h".}
# proc UE_Log2*(msg: var FString) : void {.importcpp: "UE_LOG(LogTemp, Log, *#)" .}

{.pop.}


proc getPropertyValuePtr*[T](property:FPropertyPtr, container : pointer) : ptr T {.importcpp: "GetPropertyValuePtr<'*0>(@)", header:"UPropertyCaller.h".}
proc setPropertyValuePtr*[T](property:FPropertyPtr, container : pointer, value : ptr T) : void {.importcpp: "SetPropertyValuePtr<'*3>(@)", header:"UPropertyCaller.h".}

type 
    # ActualTestSignature = 
    FNimTestBase* {.importcpp, inheritable, pure, header:  "Test/NimTestBase.h".} = object
        ActualTest* : proc (test:var FNimTestBase) : void {.cdecl.}


# proc makeFNimTestBase*(testName:FString): FNimTestBase {.importcpp:"FNimTestBase::MakeTestBase(#)".}
proc makeFNimTestBase*(testName:FString): FNimTestBase {.importcpp:"FNimTestBase(#)", constructor.}
proc reloadTest*(test:FNimTestBase):void {.importcpp:"#.ReloadTest()".}
proc testTrue*(test:FNimTestBase, msg:FString, value:bool):void {.importcpp:"#.TestTrue(@)".}


# proc runTest(this:FNimTestBasePtr, params:var FString) :bool {.importcpp:"#->RunTest(#)", header:  "Test/NimTestBase.h".}



# UClass* GetClassByName
{.push header:"ReflectionHelpers.h"}

proc getFPropertyByName*(class:UClassPtr, propName:var FString) : FPropertyPtr {.importcpp: "UReflectionHelpers::GetFPropetyByName(@)"}

proc getClassByName*(className:FString) : UClassPtr {.importcpp:"UReflectionHelpers::GetClassByName(@)".}

#NewObjectFromClass
proc newObjectFromClass*(className:UClassPtr) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}

{. pop .}



proc newUObject*[T:UObject]() : ptr T = 
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cast[ptr T](newObjectFromClass(cls)) 

