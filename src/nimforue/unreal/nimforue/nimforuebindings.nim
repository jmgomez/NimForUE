import ../coreuobject/uobject
import ../core/containers/unrealstring 



type UFunctionCaller* {.importcpp: "UFunctionCaller", inheritable, pure, header:  "UFunctionCaller.h".} = object

# proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:openarray[pointer]) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc invoke*(functionCaller: UFunctionCaller, executor:ptr UObject, returnResult:pointer) : void {.importcpp: "#.Invoke(@)", header:  "UObject/Object.h".}

proc callUFuncOn*(executor:UObjectPtr, funcName : var FString, InParams : pointer, returnResult:pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)", header:  "UFunctionCaller.h"}

proc UE_Log*(msg: FString) : void {.importcpp: "UFunctionCaller::NimForUELog(@)" header: "UFunctionCaller.h".}
# proc UE_Log*(msg: var FString) : void {.importcpp: "HelpersBindings::NimForUELog(@)" header: "HelpersBindings.h".}
# proc UE_Log2*(msg: var FString) : void {.importcpp: "UE_LOG(LogTemp, Log, *#)" .}


