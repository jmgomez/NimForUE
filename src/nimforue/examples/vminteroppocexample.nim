include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate, strutils]

import ../vm/[runtimefield, uecall]

import ../test/testutils




uClass UObjectPOC of UObject:
  (BlueprintType)
  ufunc: 
    proc instanceFunc() = 
      UE_Log "Hola from UObjectPOC instanceFunc"

    proc instanceFuncWithOneArgAndReturnTest(arg : int) : FVector = FVector(x:arg.float32, y:arg.float32, z:arg.float32)

  ufuncs(Static):
    proc callFuncWithNoArg() = 
      UE_Log "Hola from UObjectPOC"
    proc callFuncWithOneIntArg(arg : int) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc callFuncWithOneStrArg(arg : FString) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc callFuncWithTwoIntArg(arg1 : int, arg2 : int) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithTwoStrArg(arg1 : FString, arg2 : FString) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithInt32Int64Arg(arg1 : int32, arg2 : int64) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc saluteWitthTwoDifferentIntSizes2(arg1 : int64, arg2 : int32) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc callFuncWithOneObjPtrArg(obj:UObjectPtr) = 
      UE_Log "Object name: " & $obj.getName()
    proc callFuncWithObjPtrStrArg(obj:UObjectPtr, salute : FString) = 
      UE_Log "Object name: " & $obj.getName() & " Salute: " & $salute
    proc callFuncWithObjPtrArgReturnInt(obj:UObjectPtr) : int = 
      UE_Log "Object name: " & $obj.getName() 
      UE_Log "Object addr: " & $cast[int](obj)
      10
    proc callFuncWithObjPtrArgReturnObjPtr(obj:UObjectPtr) : UObjectPtr = 
      UE_Log "Object name: " & $obj.getName() 
      obj
    proc callFuncWithObjPtrArgReturnStr(obj:UObjectPtr) : FString = 
      let str = "Object name: " & $obj.getName() 
      UE_Log str
      str
    
    proc callFuncWithOneFVectorArg(vec : FVector) = 
      UE_Log "Vector: " & $vec


    proc callFuncWithOneArrayIntArg(ints : TArray[int]) = 
      UE_Log "Int array length: " & $ints.len
      for vec in ints:
        UE_Log "int: " & $vec

    proc callFuncWithOneArrayVectorArg(vecs : TArray[FVector]) = 
      UE_Log "Vector array length: " & $vecs.len
      for vec in vecs:
        UE_Log "Vector: " & $vec


    proc callThatReturnsArrayInt() : TArray[int] = makeTArray(1, 2, 3, 4, 5)

    proc receiveFloat32(arg : float32) = #: float32 = 
      UE_Log "Float32: " & $arg
      # return arg

    
    proc receiveFloat64(arg : float) = 
      UE_Log "Float64: " & $arg

    proc receiveVectorAndFloat32(dir:FVector, scale:float32) = 
      UE_Error "receiveVectorAndFloat32 " & $dir & " scale:" & $scale

    proc callFuncWithOneFVectorArgReturnFVector(vec : FVector) : FVector = 
      var vec = vec
      vec.x = 10 * vec.x
      vec.y = 10 * vec.y
      vec.z = 10 * vec.z
      vec
    
    proc callFuncWithOneFVectorArgReturnFRotator(vec : FVector) : FRotator = 
      FRotator(pitch:vec.x, yaw:vec.y, roll:vec.z)
    
#[
1. [x] Create a function that makes a call by fn name
2. [x] Create a function that makes a call by fn name and pass a value argument
  2.1 [x] Create a function that makes a call by fn name and pass a two values of the same types as argument
  2.2 [x] Create a function that makes a call by fn name and pass a two values of different types as argument
  2.3 [x] Pass a int32 and a int64
3. [x] Create a function that makes a call by fn name and pass a pointer argument
4. [x] Create a function that makes a call by fn name and pass a value and pointer argument
5. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer
  6.1 [x] Create a function that makes a call by fn name and pass a value and pointer argument and returns a string
7. [ ] Repeat 1-6 where value arguments are complex types
8. [ ] Add support for missing basic types
8. Arrays
9. TMaps

]#

# proc registerVmTests*() = 
#   unregisterAllNimTests()
#   suite "Hello":
#     ueTest "should create a ":
#       assert true == false
#     ueTest "another create a test2":
#       assert true == true

template check*(expr: untyped) =
  if not expr:
    let exprStr = repr expr
    var msg = "Check failed: " & exprStr & " " 
    raise newException(CatchableError, msg)

#maybe the way to go is by raising. Let's do a test to see if we can catch the errors in the actual actor




#Later on this can be an uobject that pulls and the actor will just run them. But this is fine as started point
uClass ANimTestBase of AActor: 
  ufunc(CallInEditor):
    proc runTests() = 
     #Traverse all the tests and run them. A test is a function that starts with "test" or "should
      let testFns = self
        .getClass()
        .getFuncsFromClass()
        .filterIt(
          it.getName().tolower.startsWith("test") or 
          it.getName().tolower.startsWith("should"))
      for fn in testFns:
        try:
          UE_Log "Running test: " & $fn.getName()
          self.processEvent(fn, nil)
        except CatchableError as e:
          UE_Error "Error in test: " & $fn.getName() & " " & $e.msg
         

uClass AActorPOCVMTest of ANimTestBase:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc testCallFuncWithNoArg() = 
      let callData = UECall( fn: makeUEFunc("callFuncWithNoArg", "UObjectPOC"))
      discard uCall(callData)
    proc testCallFuncWithOneIntArg() =
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneIntArg", "UObjectPOC"),
          value: (arg: 10).toRuntimeField()
        )
      discard uCall(callData)
    proc testCallFuncWithOneStrArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneStrArg", "UObjectPOC"),
          value: (arg: "10 cadena").toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithTwoStrArg() =
      let callData = UECall(
          fn: makeUEFunc("callFuncWithTwoStrArg", "UObjectPOC"),
          value: (arg1: "10 cadena", arg2: "Hola").toRuntimeField()
        )
      discard uCall(callData)
    proc testCallFuncWithTwoIntArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithTwoIntArg", "UObjectPOC"),
          value: (arg1: 10, arg2: 10).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithInt32Int64Arg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithInt32Int64Arg", "UObjectPOC"),
          value: (arg1: 15, arg2: 10).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithOneObjPtrArg() =
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneObjPtrArg", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithObjPtrStrArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithObjPtrStrArg", "UObjectPOC"),
          value: (obj: cast[int](self), salute: "Hola").toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithObjPtrArgReturnInt() =
      let expected = 10
      let callData = UECall(
          fn: makeUEFunc("callFuncWithObjPtrArgReturnInt", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      UE_Log $uCall(callData)

    proc testCallFuncWithObjPtrArgReturnObjPtr() =
      let callData = UECall(
          fn: makeUEFunc("callFuncWithObjPtrArgReturnObjPtr", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      let objAddr = uCall(callData).get(RuntimeField(kind:Int)).getInt()
      let obj = cast[UObjectPtr](objAddr)
      UE_Log $obj

    proc testCallFuncWithObjPtrArgReturnStr() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithObjPtrArgReturnStr", "UObjectPOC"),
          value: (obj: cast[int](self)).toRuntimeField()
        )
      let str = uCall(callData).get(RuntimeField(kind:String)).getStr()
      UE_Log "Returned string is " & str
      

    proc testCallFuncWithOneFVectorArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneFVectorArg", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      discard uCall(callData)

    proc testCallFuncWithOneArrayIntArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneArrayIntArg", "UObjectPOC"),
          value: (ints:[2, 10]).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallFuncWithOneArrayVectorArg() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneArrayVectorArg", "UObjectPOC"),
          value: (vecs:[FVector(x:12, y:10), FVector(x:12, z:1)]).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallFuncWithOneFVectorArgReturnFVector() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneFVectorArgReturnFVector", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData).get.runtimeFieldTo(FVector)

    proc testCallFuncWithOneFVectorArgReturnFRotator() = 
      let callData = UECall(
          fn: makeUEFunc("callFuncWithOneFVectorArgReturnFRotator", "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData)
    
    proc testGetRightVector() = 
      let callData = UECall(
          fn: makeUEFunc("GetRightVector", "UKismetMathLibrary"),
          value: (vec:FVector(x:12, y:10)).toRuntimeField()
        )
      UE_Log  $uCall(callData)

    proc testCallThatReturnsArrayInt() = 
      let callData = UECall(
          fn: makeUEFunc("callThatReturnsArrayInt", "UObjectPOC"),
          # value: ().toRuntimeField()
        )
      UE_Log  $uCall(callData)

    # proc test13NoStatic() = 
    #   let callData = UECall(
    #       fn: makeUEFunc("instanceFunc", "UObjectPOC"),
        
    #       value: (vec:FVector(x:12, y:10)).toJson(),
    #       self: cast[int](self)
    #     )
    #   UE_Log  $uCall(callData)
    # proc vectorToJsonTest() =
    #   UE_Log $FVector(x:10, y:10).toJson()
    #   let vectorScriptStruct = staticStruct(FVector)
    #   let structProps = vectorScriptStruct.getFPropsFromUStruct()
    #   for prop in structProps:
    #     UE_Log $prop.getName()


    proc testRuntimeFieldCanRetrieveAStructMemberByName() = 
      let vector = FVector(x:10, y:10)
      let rtStruct = vector.toRuntimeField()
      let rtField = rtStruct["x"]
      let x = rtField.getFloat()
      check x == 10.0
      UE_Log $x

    proc shouldReceiveFloat32() =
      let expected = 10.0
      let callData = UECall(
          fn: makeUEFunc("receiveFloat32", "UObjectPOC"),
          value: (arg: 10.0).toRuntimeField()
        )
      let val =  uCall(callData)#.jsonTo(float)
      # check val == expected

    proc shouldReceiveFloat64() =
      let callData = UECall(
          fn: makeUEFunc("receiveFloat64", "UObjectPOC"),
          value: (arg: 10.0).toRuntimeField()
        )
      discard uCall(callData)

    # proc shouldReceiveVectorAndFloat32() =
    #   let callData = UECall(
    #       fn: makeUEFunc("receiveVectorAndFloat32", "UObjectPOC"),
    #       value: (dir: FVector(x:10, y:10), scale: 10.0).toJson()
    #     )
    #   discard uCall(callData)