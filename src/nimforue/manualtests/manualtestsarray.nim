#this is temp until we have tests working (have to bind dyn delegates first)
include ../unreal/prelude
import std/[times,strformat, strutils, options, sugar, sequtils, json, jsonutils]
import ../typegen/[uemeta, models, ueemit]

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
    executor.setColorByStringInMesh("(R=1,G=1,B=1,A=1)")

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


proc K2_SetActorLocation(obj:UObjectPtr, newLocation: FVector, bSweep:bool, SweepHitResult: var FHitResult, bTeleport: bool) {.uebind.}

proc testVectorEntryPoint*(executor:UObjectPtr) = 
    let v : FVector = makeFVector(10, 80, 100)
    let v2 = v+v 
    let position = makeFVector(1100, 1000, 150)
    var hitResult = makeFHitResult()
    K2_SetActorLocation(executor, position, false, hitResult, true)
    executor.saySomething(v2.toString())
    # executor.saySomething(upVector.toString())


#Figure out: Array [X]
#Delegates
#Multicast Delegates
#Map



    

    # if "TEnumAsByte" in cppType: #Not sure if it would be better to just support it on the macro
    #     return cppType.replace("TEnumAsByte<","")
    #                   .replace(">", "")


    # let nimType = cppType.replace("<", "[")
    #                      .replace(">", "]")
    #                      .replace("*", "Ptr")


    # let delProp = castField[FDelegateProperty](prop)
    # if not delProp.isNil():
    #     let signature = delProp.getSignatureFunction()
    #     var signatureAsStr = "ScriptDelegate["
    #     for prop in getFPropsFromUStruct(signature):
    #         let nimType = prop.getNimTypeAsStr()
    #         signatureAsStr = signatureAsStr & nimType & ","
    #     signatureAsStr[^1] = ']'
    #     return signatureAsStr


var isExecuted = false
proc scratchpad*(executor:UObjectPtr) = 
    if isExecuted: return
    isExecuted = true

    # UE_Log("here we test back")
    let moduleName = FString("NimForUEBindings")
    # let classes = getAllClassesFromModule(moduleName)
    let ef = EFieldIterationFlags.None

    let cls = getClassByName("MyClassToTest")
    let ueType = cls.toUEType()




#Review the how 
proc scratchpadEditor*() = 
    try:
        let package = getPackageByName("NimForUEBindings")
        if not package.isNil():
            UE_Log("package is " & package.getName())
        else:
            UE_Log("package is nill")

        for c in getAllObjectsFromPackage[UNimClassBase](package):
            UE_Warn "PRE Class " & c.getName()
            for p in getFPropsFromUStruct(c):
                UE_Log "Prop " & p.getName()
            
            # if c.getName().contains("REINST"):
            #     c.conditionalBeginDestroy()
            #     UE_Log "Destroying prev" & c.getName()



    except Exception as e:
        
        UE_Warn e.msg
        UE_Warn e.getStackTrace()


#temp
type
    AActor* = object of UObject
    AActorPtr* = ptr AActor

const ueEnumType = UEType(name: "EMyTestEnum", kind: uetEnum, 
                            fields: @[
                                UEField(kind:uefEnumVal, name:"TestValue"),
                                UEField(kind:uefEnumVal, name:"TestValue2")
                            ]
                        )
genType(ueEnumType)


# uStruct FIntPropTests:
#     (BlueprintType)
#     uprop(BlueprintReadWrite):
#         propInt8 : int8
#         propInt16 : int16
#         propInt32 : int32
#         propInt64 : int64
#         propByte : byte
#         propUint16 : uint16
#         propUint32 : uint32
#         propUint64 : uint64
#         propMapFloat : TMap[FString, float]
#         propMapFloat2 : TMap[FString, float]
#         propMapFloat3 : TMap[bool, FName]
#         propVector : FVector
#         propHitResult : FHitResult
#         propActor : AActorPtr
#         propActorSubclass : TSubclassOf[UObject]
#         propSoftObject : TSoftObjectPtr[UObject]
#         propSoftClass : TSoftClassPtr[AActor]
#         propEnum : EMyTestEnum



uStruct FMyUStructDemo:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
        propString : FString
        propInt : int32
        propInt64 : int
        propInt642 : int64
        propFloat32 : float32
        # # structInt : FIntPropTests
        propEnum : EMyTestEnum
        # # propBool : bool
        # propObject : UObjectPtr
        # propClass : UClassPtr
        # propSubClass : TSubclassOf[AActor]
        # propArray : TArray[FString]
        # propArrayFloat : TArray[float]
        # propArrayBool : TArray[bool]
        # propAnother : int
        propAnother2 : int
        propAnother3 : int
        # propMapFloat : TMap[FString, float]

      
    uprop(EditAnywhere, BlueprintReadOnly):
        propReadOnly : FString
        propFloat : float
        propFloat64 : float64
        propFName : FName



uClass UObjectDsl of UObject:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        # testField : FString
       
        testFieldInt : int
        testFieldAnother : int
        testFieldAnother2 : int
        
        testFieldAnother3 : bool
        testFieldAnother321 : FString
        testFieldAnother32 : FString
        testFieldAnotherFSTRING : FString
        testFieldAnother4 : int32
        testFieldAnother5 : int32
        testFieldAnother6 : int32
        # testFieldAnother7 : int32
        # testFieldAnother8 : int32
        # testFieldAnother9 : int32
        # testFieldAnother91 : int32
        # testFieldAnother10 : int32
        # testFieldAnother120 : int32
        # testFieldAnother121 : int32
        # testFieldAnother123: int32
        # testFieldAnother124: int32
        # testFieldAnother128: int32




uClass AActorDsl of AActor:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        testField : FString
        # test2 : int
        test3 : bool
        test4 : FString
        # anotherField : FMyUStructDemo
        # anotherField2 : FString
        # anotherField3 : int32
        # anotherField4 : int32
        # anotherField5 : FString




