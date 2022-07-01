include ../unreal/prelude
import testutils
import testdata

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


        proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.} #since it isnt' type safe to call (Uobject) can be let here
        
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
 
        type Params = object
            param : FString
        
        var param = Params(param:"Hello")

        let propName = FString("DynamicDelegateOneParamProperty")
        let prop = obj.getClass().getFPropertyByName propName 

        let result = getPropertyValuePtr[FScriptDelegate](prop, obj)[]
        let funcName = makeFName("DelegateFunc")

        result.bindUFunction(obj, funcName)

        assert true
       




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
        
        obj.bindDelegateFuncToMultcasDynOneParam()

        type Params = object
            param : FString
        
        var param = Params(param:"Hello from multicast working fine")

        obj.multicastDynamicDelegateOneParamProperty.processMulticastDelegate(param.addr) 

        assert obj.bWasCalled

        obj.multicastDynamicDelegateOneParamProperty.removeAll(obj)
    
    
    ueTest "ShouldBeAbleToBindMulticastDelegateFDynamicMulticastDelegateOneParam_NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        type Params = object
            param : FString
        
        var param = Params(param:"Hello")

        let propName = FString("MulticastDynamicDelegateOneParamProperty")
        let prop = obj.getClass().getFPropertyByName propName 

        let result  = getPropertyValuePtr[FMulticastScriptDelegate](prop, obj)[]
        let funcName = makeFName("DelegateFunc")

        result.bindUFunction(obj, funcName)

        result.processMulticastDelegate(param.addr) 


        assert obj.bWasCalled
        obj.multicastDynamicDelegateOneParamProperty.removeAll(obj)


    ueTest "ShouldBeAbleToUseMulticastDelegatesFromUProps":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        #replace with addDynamic
        obj.multicastDynamicDelegateOneParamProperty.bindUFunction(obj, makeFName("DelegateFunc"))

        obj.multicastDynamicDelegateOneParamProperty.broadcast("Hey!")

        assert obj.bWasCalled 

        obj.multicastDynamicDelegateOneParamProperty.removeAll(obj)


    ueTest "ShouldBeAbleToUseExecuteInDelegatesFromUProps":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        #replace with addDynamic
        obj.dynamicDelegateOneParamProperty.bindUFunction(obj, n("DelegateFunc"))

        obj.dynamicDelegateOneParamProperty.execute("Hey!")

        assert obj.bWasCalled 

    ueTest "Should be able to implement a fn in nim and bind in to an existing delegate in ue":
            let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()


            #Params needs to be retrieved from the function so they have to be set
            proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
                stack.increaseStack()
                let obj = cast[UMyClassToTestPtr](context) 
                type Param = object
                    param0 : FString

                let params = cast[ptr Param](stack.locals)[]

                #actual func
                UE_Log("the param from the delegate is " & params.param0)

                obj.bWasCalled = true

                #end actual func
            let fnField = UEField(kind:uefFunction, name: "NewFnForDelegate", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                    )

            let fn = createUFunctionInClass(obj.getClass(), fnField, fnImpl)
            #replace with addDynamic
            obj.dynamicDelegateOneParamProperty.bindUFunction(obj, makeFName(fnField.name))

            obj.dynamicDelegateOneParamProperty.execute("Hey!")

            assert obj.bWasCalled 


    