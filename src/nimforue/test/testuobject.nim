include ../unreal/prelude
import testutils

suite "NimForUE.UObject":

    ueTest "ShouldBeAbleToGetAClassByName":
        let cls = getClassByName("Actor")

        assert not cls.isNil()
        assert cls.getName() == FString("Actor")

    ueTest  "ShouldBeAbleToCreateAObjectByClass":
        let cls = getClassByName("Actor")
        let obj = newObjectFromClass(cls)

        assert not cls.isNil()
        assert cls.getName()==(obj.getClass().getName())
    


    ueTest "ShouldBeAbleToCallAFunctionInAnUObject":
        let cls = getClassByName("MyClassToTest") 
        let obj = newObjectFromClass(cls)
        

        let expectedResult = FString("Hello World!")


        proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
        
        let result = obj.getHelloWorld()


        assert result == expectedResult

    ueTest "ShouldBeAbleToCallAStaticFunctionInAClass":
        let cls = getClassByName("MyClassToTest")

        let expectedResult = FString("Hello World!")

        proc getHelloWorld(): FString =
            type
                Params = object
                    toReturn: FString

            let cls = getClassByName("MyClassToTest")
            var params = Params()
            var fnName: FString = "GetHelloWorld"
            callUFuncOn(cls, fnName, params.addr)
            return params.toReturn


        proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
        
        let result = getHelloWorld()


        assert result == expectedResult


    ueTest "ShouldBeAbleToCallAStaticFunctionInAClassWithUEBind":
        let cls = getClassByName("MyClassToTest")

        let expectedResult = FString("Hello World!")

        proc getHelloWorld() : FString {.uebindstatic:"MyClassToTest"}

        let result = getHelloWorld()
        assert result == expectedResult


    ueTest "ShouldBeAbleToGetThePropertyNameFromAClass":
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 

        assert not prop.isNil()

        assert prop.getName() == propName


    ueTest "ShouldBeAbleToGetThePropertyValueFromAnObject":
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 
        var obj = newObjectFromClass(cls)

        let result = getPropertyValuePtr[FString](prop, obj)[]

        let expectedResult = FString("Hello World!")


        assert result == expectedResult

    ueTest "ShouldBeAbleToGetThePropertyValueFromAnObjectUsingAGetter_PreMacro":
        type 
            UMyClassToTest = object of UObject
            UMyClassToTestPtr = ptr UMyClassToTest
        
        proc testProperty(obj:UMyClassToTestPtr) : FString = 
            let cls = getClassByName("MyClassToTest")
            var propName : FString = "TestProperty"
            let prop = cls.getFPropertyByName propName 
            let result = getPropertyValuePtr[FString](prop, obj)[]
            # let result = cast[ptr FString](prop.getFPropertyValue(obj))[]
            result

        var obj = newUObject[UMyClassToTest]()

        let result = obj.testProperty
        let expectedResult = FString("Hello World!")

        assert result == expectedResult


    ueTest "ShouldBeAbleToSetThePropertyValueFromAnObject":
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 
        var obj = newObjectFromClass(cls)
        var expectedResult = FString("New Value!")

        setPropertyValuePtr(prop, obj, expectedResult.addr) 
    
        let result = getPropertyValuePtr[FString](prop, obj)[]


        assert result == expectedResult

    ueTest "ShouldBeAbleToSetThePropertyValueFromAnObject_PreMacro":
        type 
            UMyClassToTest = object of UObject
            UMyClassToTestPtr = ptr UMyClassToTest

        proc testProperty(obj:UMyClassToTestPtr) : FString = 
            let cls = getClassByName("MyClassToTest")
            var propName : FString = "TestProperty"
            let prop = cls.getFPropertyByName propName 
            let result = getPropertyValuePtr[FString](prop, obj)[]
            result 

        proc `testProperty=`(obj:UMyClassToTestPtr, val:FString) = 
            let cls = getClassByName("MyClassToTest")
            var propName : FString = "TestProperty"
            var value : FString = val 
            let prop = cls.getFPropertyByName propName
            setPropertyValuePtr[FString](prop, obj, value.addr)
            
        
        var obj = newUObject[UMyClassToTest]()
        var expectedResult = FString("New Value!")
        
        assert obj.testProperty != expectedResult
        
        obj.testProperty = expectedResult

        assert obj.testProperty == expectedResult

    #This struct is defined in Cpp. TODO: Integrate it into the macro
    type FStructToUseAsVar = object 
        testProperty : FString  

    #This enum is defined in Cpp. TODO: Integrate it into the macro
    type EMyTestEnum = enum uint8 
        TestValue,
        TestValue2



    const ueVarType = UEType(name: "UClassToUseAsVar", parent: "UObject", kind: uClass, 
                        properties: @[
                            UEProperty(name: "TestProperty", kind: "FString"),
                            ])
                            

    const ueType = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass, 
                        properties: @[
                            UEProperty(name: "TestProperty", kind: "FString"),
                            UEProperty(name: "IntProperty", kind: "int32"),
                            UEProperty(name: "FloatProperty", kind: "float32"),
                            UEProperty(name: "BoolProperty", kind: "bool"),
                            UEProperty(name: "ArrayProperty", kind: "TArray[FString]"),
                            UEProperty(name: "ObjectProperty", kind: "UClassToUseAsVarPtr"),
                            UEProperty(name: "StructProperty", kind: "FStructToUseAsVar"),
                            UEProperty(name: "ClassProperty", kind: "UClassPtr"),
                            UEProperty(name: "SubclassOfProperty", kind: "TSubclassOf[UObject]"), #Couldnt bind it
                            UEProperty(name: "EnumProperty", kind: "EMyTestEnum"), #Couldnt bind it
                            UEProperty(name: "SoftObjectProperty", kind: "TSoftObjectPtr[UObject]"), #Couldnt bind it
                            UEProperty(name: "MapProperty", kind: "TMap[FString, int32]"), #Couldnt bind it
                            UEProperty(name: "NameProperty", kind: "FName"), #Couldnt bind it
                            UEProperty(name: "DynamicDelegateOneParamProperty", kind: "FScriptDelegate"), #Not sure if I should use the type directly?
                            UEProperty(name: "MulticastDynamicDelegateOneParamProperty", kind: "FMulticastScriptDelegate"), #Not sure if I should use the type directly?
                            UEProperty(name: "bWasCalled", kind: "bool"),

                            ])



                            
    genType(ueVarType)
    genType(ueType) #Notice we wont be using genType directly



    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForFString":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult = FString("Hello from Test")
        obj.testProperty = expectedResult 
        assert expectedResult == obj.testProperty 

    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForint32":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult = int32 5
        obj.intProperty = expectedResult
        
        assert expectedResult == obj.intProperty 

    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForFloat":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult = 5.0f
        obj.floatProperty = expectedResult
        
        assert expectedResult == obj.floatProperty 



    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForBool":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult = true
        obj.boolProperty = expectedResult
        
        assert expectedResult == obj.boolProperty 



    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForUObjectProps":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult : UClassToUseAsVarPtr = newUObject[UClassToUseAsVar]()
        expectedResult.testProperty = "Hello another prop!"
        

        

        obj.objectProperty = expectedResult

        assert obj.objectProperty.testProperty == expectedResult.testProperty
    

    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForStructs_PreMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedResult = FString("Some String")

        let structProp = FStructToUseAsVar(testProperty: expectedResult)

        obj.structProperty = structProp

        assert obj.structProperty.testProperty == expectedResult


    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForUClass":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        
        let cls = getClassByName("Actor")


        obj.classProperty = cls

        assert obj.classProperty == cls
    
    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForTSubClass":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        let expectedCls = getClassByName("MyClassToTest") #Not sure if the compiler will be able to test that the classes are compatible or if it will be even neccesary to do so

        obj.subclassOfProperty = makeTSubclassOf[UMyClassToTest](expectedCls)  

        assert obj.subclassOfProperty.get() == expectedCls
 
 
    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForTEnums":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        
        let expectedValue = TestValue2

        obj.enumProperty = expectedValue

        assert obj.enumProperty == TestValue2
    


    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForTSoftObjectPtr":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        
        let expectedValue = newUObject[UMyClassToTest]()
        
        obj.softObjectProperty = makeTSoftObject(expectedValue)


        assert obj.softObjectProperty.get() == expectedValue
    

    
    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForTMaps":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    
        obj.mapProperty =  makeTMap[FString, int32]()
        obj.mapProperty.add("Hello", 5.int32)
       
        assert obj.mapProperty.num() == 1
        assert obj.mapProperty["Hello"] == 5
    

    
    ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForFName":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        obj.nameProperty = makeFName("Hello")
        

       
        assert obj.nameProperty.toFString() == FString("Hello")
    

    ueTest "ShouldBeAbleToCallprocessDelegateFDynamicDelegateOneParam_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        proc bindDelegateFuncToDelegateOneParam(obj:UMyClassToTestPtr) : void {.uebind.}
        # obj.bindDelegateFuncToDelegateOneParam()

        type Params = object
            param : FString
        
        var param = Params(param:"Hello")

        let propName = FString("DynamicDelegateOneParamProperty")
        let prop = obj.getClass().getFPropertyByName propName 

        let result = getPropertyValuePtr[FScriptDelegate](prop, obj)[]
        let funcName = makeFName("DelegateFunc")

        result.bindUFunction(obj, funcName)

        assert obj.dynamicDelegateOneParamProperty.isBound()
        
        obj.dynamicDelegateOneParamProperty.processDelegate(param.addr) 
        #This should generate a broadcast function with the following signature dynDelegate.broadcast(str:FString)
        #Should it be bind via MulticastDynamicDelegate[Params]? 

        assert obj.bWasCalled

    ueTest "ShouldBeAbleToBindAnUFunctionInADelegateFDynamicDelegateOneParam_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        let funcName = makeFName("DelegateFunc")
        obj.dynamicDelegateOneParamProperty.bindUFunction(obj, funcName)

        type Params = object
            param : FString
        
        var param = Params(param:"Hello")
        assert obj.dynamicDelegateOneParamProperty.isBound()

        obj.dynamicDelegateOneParamProperty.processDelegate(param.addr) 
        #This should generate a broadcast function with the following signature dynDelegate.broadcast(str:FString)
        #Should it be bind via MulticastDynamicDelegate[Params]? 

        assert obj.bWasCalled


    ueTest "ShouldBeAbleToBindAnUFunctionInADelegateFDynamicDelegateOneParamCallItViaBroadcast_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

         #Todo eventually do a wrapper to bind an uebind function
         #so it will look into the signature and generate it
        obj.dynamicDelegateOneParamProperty.bindUFunction(obj, makeFName("DelegateFunc"))


        type CustomScriptDelegate = object of FScriptDelegate
        #The type is just for typesafety on the CustomScriptDelegate
        proc broadcast(dynDel: ptr CustomScriptDelegate, str: FString) = 
            type Params = object
                param : FString

            var param = Params(param:str)
            let scriptDelegate : FScriptDelegate = dynDel[]
            scriptDelegate.processDelegate(param.addr) 

        var del = cast[ptr CustomScriptDelegate](obj.dynamicDelegateOneParamProperty.addr)


        assert obj.dynamicDelegateOneParamProperty.isBound()

        del.broadcast("Called from broadcast!")

        #Since this work, the syntax for binding it may be 
        #[
            TScriptDelegate[FString] and it will emmit
                - A new type with the name Like Name_ScriptDelegate_FString
                - a broadcast function that will allow to call it like above (obj.myDelegate.broadcast("params"))
                - a bindUFunction overload that will allow to bind a a delegate by proc (how to make sure the func is a ufunc?)
       
        ]#
        
        assert obj.bWasCalled



    
    ueTest "ShouldBeAbleToCallprocessMulticastDelegateFDynamicMulticastDelegateOneParam_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        proc bindDelegateFuncToMultcasDynOneParam(obj:UMyClassToTestPtr) : void {.uebind.}
        obj.bindDelegateFuncToMultcasDynOneParam()

        type Params = object
            param : FString
        
        var param = Params(param:"Hello from multicast working fine")

        obj.multicastDynamicDelegateOneParamProperty.processMulticastDelegate(param.addr) 
   
        assert obj.bWasCalled
    
    
    ueTest "ShouldBeAbleToBindMulticastDelegateFDynamicMulticastDelegateOneParam_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        
        # obj.multicastDynamicDelegateOneParamProperty.bindUFunction(obj, makeFName("DelegateFunc"))

        type Params = object
            param : FString
        
        var param = Params(param:"Hello")

        let propName = FString("MulticastDynamicDelegateOneParamProperty")
        let prop = obj.getClass().getFPropertyByName propName 

        let result : ptr FMulticastScriptDelegate = getPropertyValuePtr[FMulticastScriptDelegate](prop, obj)
        let funcName = makeFName("DelegateFunc")

        result.bindUFunction(obj, funcName)

        # obj.multicastDynamicDelegateOneParamProperty.processMulticastDelegate(param.addr) 
        
        assert obj.bWasCalled
    

