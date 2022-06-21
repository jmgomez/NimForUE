
include ../unreal/prelude
import testutils


const uePropType = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass,
            fields: @[UEField(kind:uefProp, name: "bWasCalled", uePropType: "bool")]
    )

genType(uePropType)


suite "NimForUE.Emit":
    uetest "Should be able to find a function to an existing object":
        let cls = getClassByName("EmitObjectTest")
        let fn = cls.findFunctionByName(n"ExistingFunction")

        assert not fn.isNil()

    uetest "Should be able to create a ufunction to an existing object":
        let cls = getClassByName("EmitObjectTest")
        let fnName = n"NewFunction"

        var fn = cls.findFunctionByName fnName
        assert fn.isNil()

        let newFn = newUObject[UFunction](cls, fnName)
        cls.addFunctionToFunctionMap(newFn, fnName)

        fn = cls.findFunctionByName fnName
        
        assert not fn.isNil()

        cls.removeFunctionFromFunctionMap fn
     

    ueTest "should be able to invoke a function":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

        #replace with addDynamic
        let fn = obj.getClass().findFunctionByName(n"DelegateFunc")
        type Params = object
            param0 : FString
        var param = Params(param0: "Hello!")
        
        obj.processEvent(fn, param.addr)

        assert obj.bWasCalled 



    uetest "Should be able to replace a function implementation to a new UFunction NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"FakeFunc"

        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            stack.increaseStack()
            
        var fn = obj.getClass().findFunctionByName fnName
       
        let fnPtr : FNativeFuncPtr = makeFNativeFuncPtr(fnImpl)
        
        assert not fn.isNil() 
     
        fn.setNativeFunc(fnPtr)

        obj.processEvent(fn, nil)

        assert obj.bWasCalled

        cls.removeFunctionFromFunctionMap fn
        

    uetest "Should be able to create a new function in nim and map it to a new UFunction NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"NewFunction"

        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            stack.increaseStack()


    

            
        var fn = newUObject[UFunction](cls, fnName)
        fn.functionFlags = FUNC_Native
        fn.Next = cls.Children 
        cls.Children = fn

        let fnPtr : FNativeFuncPtr = makeFNativeFuncPtr(fnImpl)
        fn.setNativeFunc(fnPtr)
        fn.staticLink(true)

        obj.processEvent(fn, nil)

        assert obj.bWasCalled
        

        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        


        
