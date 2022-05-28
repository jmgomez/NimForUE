#this is temp until we have tests working (have to bind dyn delegates first)
import ../macros/uebind
import ../unreal/coreuobject/uobject
import ../unreal/core/containers/[unrealstring, array]
import ../unreal/core/math/[vector]
import ../unreal/core/[enginetypes]
import ../unreal/nimforue/nimForUEBindings
import std/[times]
import strformat


{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
""".}

proc saySomething(obj:UObjectPtr, msg:FString) : void {.uebind.}


proc testArrays(obj:UObjectPtr) : TArray[FString] {.uebind.}

proc testMultipleParams(obj:UObjectPtr, msg:FString,  num:int) : FString {.uebind.}

proc boolTestFromNimAreEquals(obj:UObjectPtr, numberStr:FString, number:cint, boolParam:bool) : bool {.uebind.}

proc setColorByStringInMesh(obj:UObjectPtr, color:FString): void  {.uebind.}

var returnString = ""

proc printArray(obj:UObjectPtr, arr:TArray[FString]) =
    for str in arr: #add posibility to iterate over
        obj.saySomething(str) 

proc testArrayEntryPoint*(executor:UObjectPtr) =
    let msg = testMultipleParams(executor, "hola", 10)

    executor.saySomething(msg)

    executor.setColorByStringInMesh("(R=1.0,G=0.35,B=0,A=1)")

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

    arr2.add($now() & " is it Nim TIME?")

    # printArray(executor, arr)
    let lastElement : FString = arr2[0]
    # let lastElement = makeFString("")
    returnString = "number of elements " & $arr.num() & "the element last element is " & lastElement

    # let nowDontCrash = 
    # let msgArr = "The length of the array is " & $ arr.num()
    executor.saySomething(returnString)
    executor.printArray arr2

    executor.saySomething("length of the array5 is " & $ arr2.num())
    arr2.removeAt(0)
    arr2.remove("hola5")
    executor.saySomething("length of the array2 is after removed yeah " & $ arr2.num())

proc K2_SetActorLocation(obj: UObjectPtr; newLocation: FVector; bSweep: bool;
                         SweepHitResult: var FHitResult; bTeleport: bool) =
  type
    Params = object
      newLocation: FVector
      bSweep: bool
      SweepHitResult: FHitResult
      bTeleport: bool

  var params = Params(newLocation: newLocation, bSweep: bSweep,
                      SweepHitResult: SweepHitResult, bTeleport: bTeleport)
  var fnName: FString = "K2_SetActorLocation"
  callUFuncOn(obj, fnName, params.addr)



# proc K2_SetActorLocation(obj:UObjectPtr, newLocation: FVector, bSweep:bool, SweepHitResult: var FHitResult, bTeleport: bool) {.uebind.}

proc testVectorEntryPoint*(executor:UObjectPtr) = 
    let v : FVector = makeFVector(10, 50, 30)
    let v2 = v+v 
    let position = makeFVector(1000, 500, 100)
    var hitResult = makeFHitResult()
    K2_SetActorLocation(executor, position, false, hitResult, true)
    executor.saySomething(v2.toString())
    executor.saySomething(upVector.toString())



