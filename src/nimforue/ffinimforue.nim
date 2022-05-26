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
import strformat

# proc testArrays(obj: UObjectPtr): TArray[FString] =
#   type
#     Params = object
#       toReturn: TArray[FString]

#   var params = Params()
#   var fnName: FString = "TestArrays"
#   callUFuncOn(obj, fnName, params.addr)
#   return params.toReturn



proc saySomething(obj:UObjectPtr, msg:FString) : void {.uebind.}


proc testArrays(obj:UObjectPtr) : TArray[FString] {.uebind.}

proc testMultipleParams(obj:UObjectPtr, msg:FString,  num:int) : FString {.uebind.}

proc boolTestFromNimAreEquals(obj:UObjectPtr, numberStr:FString, number:cint, boolParam:bool) : bool {.uebind.}

proc setColorByStringInMesh(obj:UObjectPtr, color:FString): void  {.uebind.}
#define on config.nims
const genFilePath* {.strdefine.} : string = ""

#it's here for ref
#[
proc testCallUFuncOnWrapper(executor:UObjectPtr; str:FString; n:int) : FString    =     
    type Params = object 
            str: FString
            n: int
            toReturn: FString #Output paramaeters 
        
    var parms = Params(str: str, n: n) 
    var funcName = makeFString("TestMultipleParams")
    callUFuncOn(executor, funcName, parms.addr)
    return parms.toReturn
]#

var loaded = false
proc NimMain() {.importc.}


# call functions without obj.
proc printArray(obj:UObjectPtr, arr:TArray[FString]) : void = 
    for str in arr: #add posibility to iterate over
        obj.saySomething(str) 


{.push exportc, cdecl, dynlib.} 

# proc testPointerBoolOut(boolean: var bool) : ptr bool {.ffi:genFilePath.} = 
#     return boolean.addr


var returnString = ""
proc testCallUFuncOn(obj:pointer) : void  {.ffi:genFilePath}  = 
    if not loaded: #TODO move this to a global init for nimforue
        loaded = true
        NimMain()

    let executor = cast[UObjectPtr](obj)
 
    let msg = testMultipleParams(executor, "hola", 10)

    executor.saySomething(msg)

    executor.setColorByStringInMesh("(R=0.0 ,G=1,B=1,A=1)")

    if executor.boolTestFromNimAreEquals("5", 5, true) == true:
        executor.saySomething("true")
    else:
        executor.saySomething("false" & $ sizeof(bool))

    let arr = testArrays(executor)
    let number = arr.num()

    # let str = $arr.num()
    
    arr.add("hola")
    arr.add("hola2")
    let arr2 = makeTArray[FString]()
    arr2.add("hola3")
    arr2[0] = "hola3-replaced"

    arr2.add("hola5")
   
    # printArray(executor, arr)
    let lastElement : FString = arr2[0]
    # let lastElement = makeFString("")
    returnString = "number of elements " & $arr.num() & "the element last element is " & lastElement

    # let nowDontCrash = 
    # let msgArr = "The length of the array is " & $ arr.num()
    executor.saySomething(returnString)
    executor.printArray arr2
    
    executor.saySomething("length of the array2 is " & $ arr2.num())
    arr2.removeAt(0)
    arr2.remove("hola5")
    executor.saySomething("length of the array2 is after removed " & $ arr2.num())
    

{.pop.}


