

include unreal/prelude


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