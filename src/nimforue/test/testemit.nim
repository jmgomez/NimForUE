
include ../unreal/prelude
import strutils
import strformat
import testutils

#TODO make this public and use it from test utils
const uePropType = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass,
            fields: @[
                UEField(kind:uefProp, name: "bWasCalled", uePropType: "bool"),
                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32"),
            
            ]
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
        let fn = createUFunctionInClass(fnName, cls, FUNC_Native, fnImpl, @[])

        obj.processEvent(fn, nil)

        assert obj.bWasCalled
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        


    uetest "Should be able to create a new function that accepts a parameter in nim":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"NewFunction"


        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            let fn = stack.node
            let paramProp = cast[FPropertyPtr](fn.ChildProperties)
            assert not paramProp.isnil()
            let paramVal : ptr FString = getPropertyValuePtr[FString](paramProp, stack.locals)
            assert not paramVal.isNil()
            #actual func
            obj.testProperty = paramVal[]
            #end actual func
            stack.increaseStack()

        let props = @[UEField(kind:uefProp, name: "TestProperty", uePropType: "FString")]


        let fn = createUFunctionInClass(fnName, cls, FUNC_Native, fnImpl, props)

        type Param = object
            param0 : FString
        
        var param = Param(param0: "FString Parameter")

        obj.processEvent(fn, param.addr)

        assert obj.bWasCalled
        assert fn.numParms == 1
        assert obj.testProperty.equals(param.param0)
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 

    
    ueTest "Should be able to create a new function that accepts two parameters in nim":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"NewFunction2Params"


        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            let fn = stack.node
            type Param = object
                param0 : int32
                param1 : FString

            let params = cast[ptr Param](stack.locals)[]

            #actual func
            obj.intProperty = params.param0 
            obj.testProperty = params.param1
            #end actual func
            stack.increaseStack()

        let props = @[UEField(kind:uefProp, name: "IntProperty", uePropType: "int32"), 
                    UEField(kind:uefProp, name: "TestProperty", uePropType: "FString")]


        let fn = createUFunctionInClass(fnName, cls, FUNC_Native, fnImpl, props)

        proc newFunction2Params(obj:UMyClassToTestPtr, param:int32, param2:FString) {.uebind .} 

        let expectedInt : int32 = 3
        let expectedStr = "Whatever"
        obj.newFunction2Params(expectedInt, expectedStr)
        # obj.processEvent(fn, param.addr)

        assert obj.bWasCalled
        assert fn.numParms == 2
        assert obj.intProperty == expectedInt
        assert obj.testProperty.equals(expectedStr)
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        
        


        


