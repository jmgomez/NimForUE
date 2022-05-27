#HERE ALL METHODS USES TO COMUNICATE VIA FFI WITH UNREAL
#ALSO export the UEConfig type to Cpp (not sure if it has to be done in the other project)

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
""".}

import unreal/coreuobject/uobject
import unreal/core/containers/[unrealstring, array]
import unreal/nimforue/nimForUEBindings
import macros/[ffi, uebind]
import std/[times]
import strformat
import manualtests/manualtestsarray

#define on config.nims
const genFilePath* {.strdefine.} : string = ""

proc testCallUFuncOn(obj:pointer) : void  {.ffi:genFilePath}  = 
    let executor = cast[UObjectPtr](obj)
    testArrayEntryPoint(executor)
    testVectorEntryPoint(executor)