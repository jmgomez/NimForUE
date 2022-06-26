
include ../unreal/prelude
import strutils
import strformat
import testutils
import unittest
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



    ueTest "Should be able to replace a function implementation to a new UFunction NoMacro":
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
        


    ueTest "Should be able to create a new function in nim and map it to a new UFunction NoMacro":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            stack.increaseStack()

        let fnField = UEField(kind:uefFunction, name:"NewFuncNoParams", fnFlags: FUNC_Native, 
                            signature: @[
                               
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        obj.processEvent(fn, nil)

        assert obj.bWasCalled
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        


    ueTest "Should be able to create a new function that accepts a parameter in nim":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()
        let fnName =n"NewFunction"


        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            let fn = stack.node
            let paramProp = cast[FPropertyPtr](fn.childProperties)
            assert not paramProp.isnil()
            let paramVal : ptr FString = getPropertyValuePtr[FString](paramProp, stack.locals)
            assert not paramVal.isNil()
            #actual func
            obj.testProperty = paramVal[]
            #end actual func
            stack.increaseStack()

        let fnField = UEField(kind:uefFunction, name:"NewFunction", fnFlags: FUNC_Native, 
                    signature: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                    ]
        )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

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

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

            let params = cast[ptr Param](stack.locals)[]

            #actual func
            obj.intProperty = params.param0 
            obj.testProperty = params.param1
            #end actual func
            stack.increaseStack()



        let fnField = UEField(kind:uefFunction, name:"NewFunction2Params", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFunction2Params(obj:UMyClassToTestPtr, param:int32, param2:FString) {.uebind .} 

        let expectedInt : int32 = 3
        let expectedStr = "Whatever"
        obj.newFunction2Params(expectedInt, expectedStr)

        assert obj.bWasCalled
        assert fn.numParms == 2
        assert obj.intProperty == expectedInt
        assert obj.testProperty.equals(expectedStr)
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        
        
    ueTest "Should be able to create a new function that accepts two parameters and returns":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

            var params = cast[ptr Param](stack.locals)[]
            let str = $ params.param0 & params.param1
            var toReturn : FString = str

            let returnProp = stack.node.getReturnProperty()
            returnProp.initializeValueInContainer(result)
            setPropertyValuePtr[FString](returnProp, result, toReturn.addr)         

            stack.increaseStack()

        
        let fnField = UEField(kind:uefFunction, name:"NewFunction2ParamsAndReturns2", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "ReturnProp", uePropType: "FString", propFlags:CPF_ReturnParm or CPF_Parm),
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        proc newFunction2ParamsAndReturns2(obj:UMyClassToTestPtr, param:int32, param2:FString) : FString {.uebind .} 
        let expectedResult = $ 10 & "Whatever"

        let result = obj.newFunction2ParamsAndReturns2(10, "Whatever")
       
        assert obj.bWasCalled
        assert fn.numParms == 3
        assert result.equals(expectedResult)
        
        # #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        
        
        
    ueTest "Should be able to create a new function that accepts two parameters and returns and int":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result:pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString


            var params = cast[ptr Param](stack.locals)[]
            var value : int32 = 4

            let returnProp = stack.node.getReturnProperty()
            returnProp.initializeValueInContainer(result)
            setPropertyValuePtr[int32](returnProp, result, value.addr)

            stack.increaseStack()

        
        let fnField = UEField(kind:uefFunction, name:"NewFunction2ParamsAndReturns", fnFlags: FUNC_Native, 
                            signature: @[
                                UEField(kind:uefProp, name: "ReturnProp", uePropType: "int32", propFlags:CPF_ReturnParm or CPF_Parm),
                                UEField(kind:uefProp, name: "IntProperty", uePropType: "int32", propFlags:CPF_Parm), 
                                UEField(kind:uefProp, name: "TestProperty", uePropType: "FString", propFlags:CPF_Parm)
                            ]
                )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)

        proc newFunction2ParamsAndReturns(obj:UMyClassToTestPtr, param:int32, param2:FString) : int32 {.uebind .} 

        let result = obj.newFunction2ParamsAndReturns(10, "Whatever")
        assert obj.bWasCalled
        assert fn.numParms == 3
        check result == 4
        
        # #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        
    
    ueTest "Should be able to create a new function that accepts parameters as out":
        let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
        var cls = obj.getClass()

        #Params needs to be retrieved from the function so they have to be set
        proc fnImpl(context:UObjectPtr, stack:var FFrame,  result: pointer):void {. cdecl .} =
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : int32

            var params = cast[ptr Param](stack.locals)[]
            let fn = stack.node
            #actual func
            params.param0 = 5
            params.param1 = 5

          

            #end actual func
            #we know here there is only one, but they can be matched by name if when generating the params we use the same name
            #for the uprop. Since emited functions can only be emited by nim, we should be good by doing so.
            let outParamProp = fn.getPropsWithFlags(CPF_OutParm)[0]
            setPropertyValuePtr[int32](outParamProp, params.addr, params.param0.addr)


            stack.increaseStack()



        let fnField = UEField(kind:uefFunction, name:"NewFuncOutParams", fnFlags: FUNC_Native or FUNC_HasOutParms, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param1", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm), 
                                UEField(kind:uefProp, name: "Param2", uePropType: "int32", propFlags:CPF_Parm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFuncOutParams(obj:UMyClassToTestPtr, param:var int32, param2: int32) {.uebind .} 

        var param0 : int32 = 1
        var param1 : int32  = 1
        obj.newFuncOutParams(param0, param1)

        assert obj.bWasCalled
        assert fn.numParms == 2

        assert param0 == 5 #only this one is changed
        assert param1 == 1
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        


        


