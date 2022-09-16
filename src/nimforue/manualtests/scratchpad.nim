#this is temp until we have tests working (have to bind dyn delegates first)
include ../unreal/prelude
import std/[times, strformat, strutils, options, sugar, sequtils, json, jsonutils]
import ../typegen/[uemeta, models]

# proc saySomething(obj: UObjectPtr, msg: FString): void {.uebind.}


# proc testArrays(obj: UObjectPtr): TArray[FString] {.uebind.}

# proc testMultipleParams(obj: UObjectPtr, msg: FString,
#         num: int): FString {.uebind.}

# proc boolTestFromNimAreEquals(obj: UObjectPtr, numberStr: FString, number: cint,
#         boolParam: bool): bool {.uebind.}

# proc setColorByStringInMesh(obj: UObjectPtr, color: FString): void {.uebind.}

var returnString = ""

proc printArray(obj: UObjectPtr, arr: TArray[FString]) = discard
    # for str in arr: #add posibility to iterate over
    #     obj.saySomething(str)

proc testArrayEntryPoint*(executor: UObjectPtr) = discard
    # let msg = testMultipleParams(executor, "hola", 10)

    # executor.saySomething(msg)
    # executor.setColorByStringInMesh("(R=1,G=1,B=1,A=1)")

    # if executor.boolTestFromNimAreEquals("5", 5, true) == true:
    #     executor.saySomething("true")
    # else:
    #     executor.saySomething("false" & $ sizeof(bool))

    # let arr = testArrays(executor)
    # let number = arr.num()


    # # let str = $arr.num()


    # arr.add("hola")
    # arr.add("hola2")
    # let arr2 = makeTArray[FString]()
    # arr2.add("hola3")
    # arr2[0] = "hola3-replaced"

    # arr2.add($now() & " is it Nim TIME?")

    # # printArray(executor, arr)
    # let lastElement: FString = arr2[0]
    # # let lastElement = makeFString("")
    # returnString = "number of elements " & $arr.num() &
    #         "the element last element is " & lastElement

    # # let nowDontCrash =
    # # let msgArr = "The length of the array is " & $ arr.num()
    # executor.saySomething(returnString)
    # executor.printArray arr2

    # executor.saySomething("length of the array5 is " & $ arr2.num())
    # arr2.removeAt(0)
    # arr2.remove("hola5")
    # executor.saySomething("length of the array2 is after removed yeah " & $
    #         arr2.num())


# proc K2_SetActorLocation(obj: UObjectPtr, newLocation: FVector, bSweep: bool,
#         SweepHitResult: var FHitResult, bTeleport: bool) {.uebind.}

proc testVectorEntryPoint*(executor: UObjectPtr) =
    let v: FVector = makeFVector(10, 80, 100)
    let v2 = v+v
    let position = makeFVector(1100, 1000, 150)
    var hitResult = makeFHitResult()
    # K2_SetActorLocation(executor, position, false, hitResult, true)
    # executor.saySomething(v2.toString())
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
proc scratchpad*(executor: UObjectPtr) =
    if isExecuted: return
    isExecuted = true

    # UE_Log("here we test back")
    let moduleName = FString("NimForUEBindings")
    let classes = getAllClassesFromModule(moduleName)
    let ef = EFieldIterationFlags.None

    let cls = getClassByName("MyClassToTest")
    let ueType = cls.toUEType()


 

#temp

type
    ACharacter* = object of AActor
    ACharacterPtr* = ptr ACharacter
    ATestActor* = object of AActor
    
    ANimForUEDemoCharacter* = object of ACharacter



uClass ANimGameCharTest of ANimForUEDemoCharacter:
    (BlueprintType, Blueprintable)
    uprop(BlueprintReadWrite):
        testName : FString


const ueEnumType = UEType(name: "EMyTestEnum", kind: uetEnum,
                            fields: @[
                                UEField(kind: uefEnumVal, name: "TestValue"),
                                UEField(kind: uefEnumVal, name: "TestValue2")
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
        propString: FString
        propInt: int32
        propInt64: int
        propInt642: int64
        propFloat32: float32
        # structInt : FIntPropTests
        # propEnum : EMyTestEnum
        propBool: bool
        propObject: UObjectPtr
        propClass: UClassPtr
        propSubClass: TSubclassOf[AActor]
        propArray: TArray[FString]
        propArrayFloat: TArray[float]
        propArrayBool: TArray[bool]
        propAnother: int
        propAnother2: int
        propAnother3: int
        propAnother22: int
        propAnother31: int
        # propMapFloat : TMap[FString, float]


    uprop(EditAnywhere, BlueprintReadOnly):
        propReadOnly: FString
        propFloat: float
        propFloat64: float64
        propFName: FName


uClass UObjectDsl of UObject:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        # testField : FString

        testFieldInt: int = 100
        testFieldAnother: FString = "hello world!!"
        testFieldAnother2: bool = true

        testFieldAnother3: bool
        testFieldAnother321: FString
        testFieldAnother32: FString
        testFieldAnotherFSTRING: FString
        testFieldAnother4: int32
        testFieldAnother5: int32
        testFieldAnother6: int32
        # testFieldAnother7 : int32
        testFieldAnother8: int32
        # testFieldAnother9 : int32
        # testFieldAnother91 : int32
        testFieldAnother10: int32
        testFieldAnother120: int32
        testFieldAnother121: int32
        testFieldAnother123: int32
        # testFieldAnother124: int32
        # testFieldAnother128: int32
 
    # type FDynamicMulticastDelegateOneParamTest = object of UDelegateFunction
    # type FDynamicDelegateOneParamTest = object of UDelegateFunction
    # genDelegate(UEField(kind:uefDelegate, name: "DynamicMulticastDelegateOneParamTest", delKind:uedelMulticastDynScriptDelegate, delegateSignature: @["FString"]))
    # genDelegate(makeFieldAsMulDel("DynamicMulticastDelegateOneParamTest", @["FString"]))

    # type Whatever* = FDynamicMulticastDelegateOneParamTest


uEnum EMyEnumCreatedInDsl:
    (BlueprintType)
    WhateverEnumValue
    SomethingElse




uDelegate FMyDelegate(str: FString, number: FString, another:int)
uDelegate FMyDelegate2Params(str: FString, param: TArray[FString])
uDelegate FMyDelegateNoParams()



uClass UComponentWithoutProps of UActorComponent:
    (BlueprintType, Blueprintable, BlueprintSpawnableComponent)

uClass UNimTestComponent of UActorComponent:
    (BlueprintType, Blueprintable, BlueprintSpawnableComponent)#BlueprintSpawnableComponent
    uprop(EditAnywhere, BluerpintReadWrite):
        propString : FString
    uprop(EditAnywhere, BlueprintAssignable):
        onWhatever : FMyDelegate


# proc nimComponentConstructor(initializer: var FObjectInitializer) {.cdecl.} = 
#     var obj = ueCast[UNimTestComponent](initializer.getObj())
#     #call first cpp constructor:
#     #maybe we should add default constructor and call only the parent constructor here?
#     #if so, we could automatize it so it just call it first on the macro itself. 
#     obj.getClass().getFirstCppClass().classConstructor(initializer)
#     obj.propString = "Hey CDO modified here"
#     #first
#     UE_Warn "Class Constructor called from for the UNimTestComponent!!"

# addClassConstructor("UNimTestComponent", nimComponentConstructor)


uClass UObjectNim of UObject:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        testField: FString
        testField2: FString 
        anoptherField : int

uFunctions:
    (BlueprintPure, self: UObjectNimPtr, Static)
    proc addTwoNumbers3(param: int, param2: int) : int  = param + param2
    proc addTwoNumbers4(param: int, param2: int) : int  = param + param2
    proc addTwoNumbers5(param: int, param2: int) : int  = 
        UE_Warn "Hello from object" & self.getName()
        param + param2 

    proc helloObject(param: FString): FString {. CallInEditor .} =
        UE_Warn "Hello from object" & param

    proc helloObjectNimParam(param: FString): int {.ufunc.} =
        UE_Warn "Hello from object2 " & param
        45002
    proc addTwoNumbers(param: int, param2: int) : int  = param + param2
    proc addTwoNumbersTest(param: int, param2: int) : FString {.BlueprintPure.}  = $(param + param2)
    proc addTwoNumbersTest3(param: int, param2: int) : FString {.BlueprintPure.}  = $(param + param2)
    proc addTwoNumbersTest4(param: int, param2: int) : FString {.BlueprintPure.}  = $(param + param2)
    proc addTwoNumbersTest9(param: int, param2: int) : int {.BlueprintPure.}  = param + param2
    proc addTwoNumbers2(param: int, param2: int) : int {.ufunc BlueprintCallable .} = param + param2
    proc returnObjectTest(param: int, param2: int) : UObjectNimPtr {.ufunc.} =
        UE_Warn "Hello from object " & $param
        newUObject[UObjectNim](self)

# proc objectNimConstructor(initializer: var FObjectInitializer) {.cdecl.} = 
#     var obj = ueCast[UObjectNim](initializer.getObj())
#     #call first cpp constructor:
#     #maybe we should add default constructor and call only the parent constructor here?
#     #if so, we could automatize it so it just call it first on the macro itself. 
#     obj.getClass().getFirstCppClass().classConstructor(initializer)
#     obj.testField = "Hey CDO modified here another"
#     #first
#     UE_Warn "Class Constructor Called from for the UObjectNim!!"

# addClassConstructor("UObjectNim", objectNimConstructor)



uClass AActorDslParentNim of ATestActor:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        testFieldparent: FString


uFunctions:
    proc receiveBeginPlay(self:AActorDslParentNimPtr)  = 
        UE_Error("begin play called in actor DSL parent nim")



func calcSomething(x:int32):int32 = x * 2
uClass AActorDsl of AActorDslParentNim:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite):
        testField: FString = self.getName()
        testBoolConstructor : bool 
        testBoolDefault : bool = true
        test9: float  
        anotherField3: int32 = 21       
        anotherField2: int32 = calcSomething(200)
        anotherField1: int32 = 120
        anotherFieldArr: TArray[int32]
        anotherFieldEnum: EMyTestEnum
        nimCreatedDsl: EMyEnumCreatedInDsl = SomethingElse

    uprop(EditAnywhere, BlueprintReadWrite):
        nimTestComp: UNimTestComponentPtr
        nimTestComp2: UNimTestComponentPtr = initializer.createDefaultSubobject[:UNimTestComponent](n"NimTestComponent2")
        objectNim: UObjectNimPtr =  initializer.createDefaultSubobject[:UObjectNim](n"Object")
        objectNim2: UObjectNimPtr 


    uprop(BlueprintReadWrite, BlueprintAssignable, BlueprintCallable):
        multicastDynOneParamNimAnother: FMyDelegate
        multicastDynOneParamNimAnother2Params: FMyDelegate2Params
        multicastDel: FMyDelegateNoParams
        anotherField5 : FString


# proc actorDslConstructor(initializer: var FObjectInitializer) {.cdecl.} = 
#     var obj = ueCast[AActorDsl](initializer.getObj())
#     #call first cpp constructor:
#     #maybe we should add default constructor and call only the parent constructor here?
#     #if so, we could automatize it so it just call it first on the macro itself. 
#     obj.getClass().getFirstCppClass().classConstructor(initializer)
#     obj.nimTestComp = initializer.createDefaultSubobject[:UNimTestComponent](n"NimTestComponent")
#     obj.objectNim = initializer.createDefaultSubobject[:UObjectNim](n"Object")
#     obj.test3 = 2323
#     #first
#     UE_Warn "Class Constructor Called from for the actorDsl!!"

# addClassConstructor("AActorDsl", actorDslConstructor)

proc actorDslConstructor(self2:AActorDslPtr, initializer:FObjectInitializer) {.uConstructor.} = 
    self2.nimTestComp = initializer.createDefaultSubobject[:UNimTestComponent](n"NimTestComponent")
    self2.objectNim2 = initializer.createDefaultSubobject[:UObjectNim](n"Object2")
    self2.testBoolConstructor = true

    #first
    UE_Warn "Class Constructor Called for the actorDsl via the macro!"

#test constructor on NimComponent and on a Regular Object (then do a test over the default constructor approach)




proc helloActorDsl(self: AActorDslPtr): void  {.ufunc.}=
    UE_Warn "Hello from Aactor"

proc helloActorDsl2(self: AActorDslPtr): void  {.ufunc.}=
    UE_Warn "Hello from Aactor2"


proc notifyActorBeginOverlap(self: AActorDslPtr, otherActor:AActorPtr) {.ufunc.}  =
    UE_Log "Actor overlaped whatev1"

uFunctions:
    (BlueprintCallable, self: AActorDslPtr)

    #TODO handle the prefixes so the user can just use the same name
    proc beginPlay()   =        
        UE_Warn "Hello begin play from Aactor child in NIm" & self.getName()
        self.testBoolConstructor = true
        self.nimTestComp.onWhatever.broadcast("whaaat", "asd", 45)
        

    # proc tick(self: AActorDslPtr, deltaSeconds:float32): void  =
    #     UE_Warn "Hello begin play from Aactor whatever takes a lot of time about seem to work5 seconds" & self.getName()

    proc implmentableEventTest() {.BlueprintImplementableEvent.} 
    

    proc callEditorTest()  {.CallInEditor.} = 
        # discard 
        UE_Log "Hello from the editor5"
        self.implmentableEventTest() #call the function above instead of the blueprint one when being overriden
        var str:FString = ""
        # self.implmentableEventTestWithReturn("echo", str)
        UE_Log "Called from nim and returns  " & $ str

    proc userConstructionScript() =
        UE_Warn "Hello from the construction script, pretty cool" & self.getName()
    
    proc addTwoNumbers6(param: TArray[int], param2: var TArray[int], param3: var bool) : void  = 
        param2 = param.toSeq().map(x=>x*x).toTArray()
        

    proc anotherFn(paramOut: var bool, test : FString) : void  = 
        paramOut = true

    proc another2() : FString = "another"

uFunctions:
    (BlueprintCallable, this:AActorDslPtr)
    proc anotherFunction(test:int) : FString {.BlueprintPure.} =  "Whatever"
    proc sayHelloNewWay() {. CallInEditor .} = 
        UE_Log "hello" &  this.getName




uClass ANimCharacter of ACharacter:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadOnly):
        jumpSpeed : FString

uFunctions:
    (BlueprintCallable)
    proc onJumped(self:ANimCharacterPtr) = 
        UE_Warn "onJumped snim"
    proc didJump(self:ANimCharacterPtr) = 
        UE_Warn "didJump nim"










type UMyClassToDeriveToTestUFunctions = object of UObject

uClass UMyClassToDeriveToTestUFunctionsNim of UMyClassToDeriveToTestUFunctions:
    (BlueprintType, Blueprintable)
    uprop(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
        testField: FString
        testField3: FString


proc implementableEventTest(self:UMyClassToDeriveToTestUFunctionsNimPtr, param:FString) : void {.ufunc, BlueprintCallable.} =
    UE_Warn "Hello from nim modified " & param
    discard




#Review the how
proc scratchpadEditor*() =
    try:
        let nueBingingsPkg = getPackageByName("NimForUEBindings")

        # for obj in getAllObjectsFromPackage[UEnum](nueBingingsPkg):
        #     UE_Warn "Found enum  at NimForUEBindings " & obj.getName()
        # for obj in getAllObjectsFromPackage[UEnum](nimPackage):
        #     UE_Warn "Found enum at Nim " & obj.getName()
        for obj in getAllObjectsFromPackage[UFunction](getPackageByName("Engine")):
            if obj.getName() == "ReceiveBeginPlay":
                UE_Warn "Found function at " & obj.getOuter().getName()
                UE_Log "Flags are " & $uint32(obj.functionFlags)
    except Exception as e:
        echo ""
        UE_Warn e.msg
        UE_Warn e.getStackTrace() 


