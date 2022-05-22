#HERE ALL METHODS USES TO COMUNICATE VIA FFI WITH UNREAL
#ALSO export the UEConfig type to Cpp (not sure if it has to be done in the other project)

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
""".}

import unreal/coreuobject/uobject
import unreal/core/containers/unrealstring
import unreal/nimforue/nimForUEBindings
import macros/[ffi, uebind]
import strformat



proc saySomething(obj:UObjectPtr, msg:FString) : void {.uebind.}
proc testMultipleParams(obj:UObjectPtr, msg:FString,  num:int) : FString {.uebind.}

proc setColorByStringInMesh(obj:UObjectPtr, color:FString): void  {.uebind.}
#define on config.nims
const genFilePath* {.strdefine.} : string = ""

{.push exportc, cdecl, dynlib.} 

proc testCallUFuncOn(obj:pointer) : void  {.ffi:genFilePath}  = 
   let executor = cast[UObjectPtr](obj)

   executor.saySomething("This isw a test function")
   
   executor.setColorByStringInMesh("(R=1.0,G=1.0,B=0,A=1)")

    # discard o.callUFuncOn("test") 
{.pop.}

