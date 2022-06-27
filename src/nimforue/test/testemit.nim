
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


#[
    #define P_GET_PROPERTY(PropertyType, ParamName)													\
	PropertyType::TCppType ParamName = PropertyType::GetDefaultPropertyValue();					\
	Stack.StepCompiledIn<PropertyType>(&ParamName);

#define P_GET_PROPERTY_REF(PropertyType, ParamName)												\
	PropertyType::TCppType ParamName##Temp = PropertyType::GetDefaultPropertyValue();			\
	PropertyType::TCppType& ParamName = Stack.StepCompiledInRef<PropertyType, PropertyType::TCppType>(&ParamName##Temp);

    DEFINE_FUNCTION(UFunctionTestObject::execTestReturnStringWithParamsOut)
	{
		P_GET_PROPERTY(FStrProperty,Z_Param_A);
		P_GET_PROPERTY(FIntProperty,Z_Param_B);
		P_GET_PROPERTY_REF(FStrProperty,Z_Param_Out_Out);
		P_FINISH;
		P_NATIVE_BEGIN;
		P_THIS->TestReturnStringWithParamsOut(Z_Param_A,Z_Param_B,Z_Param_Out_Out);
		P_NATIVE_END;
	}
	DEFINE_FUNCTION(UFunctionTestObject::execTestReturnStringWithParams)
	{
		P_GET_PROPERTY(FStrProperty,Z_Param_A);
		P_GET_PROPERTY(FIntProperty,Z_Param_B);
		P_FINISH; //increaseStack
		P_NATIVE_BEGIN;
		*(FString*)Z_Param__Result=P_THIS->TestReturnStringWithParams(Z_Param_A,Z_Param_B);
		P_NATIVE_END;
	}
]#

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
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            
            
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
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true

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
            stack.increaseStack()
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
            stack.increaseStack()
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
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString

            var params = cast[ptr Param](stack.locals)[]
            let str = $ params.param0 & params.param1
            let cstr : cstring = str.cstring
            var toReturn : FString = makeFString(cstr) #Needs to call the constructor so it allocates

            cast[ptr FString](result)[] = toReturn

            # let returnProp = stack.node.getReturnProperty()
            # returnProp.initializeValueInContainer(result)
            # setPropertyValuePtr[FString](returnProp, result, toReturn.addr)         


            let val : FString = cast[ptr FString](result)[]
            UE_Log("The value of result is " & val)

        
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
            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : FString


            var params = cast[ptr Param](stack.locals)[]
            var value : int32 = 4


            cast[ptr int32](result)[] = value

            # let returnProp = stack.node.getReturnProperty()
            # returnProp.initializeValueInContainer(result)
            # setPropertyValuePtr[int32](returnProp, result, value.addr)


        
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
            var defaultPropValueCppTemp : int32 = 0
            var outValue = stepCompiledInRef[int32, FIntProperty](stack.addr, (defaultPropValueCppTemp.addr), nil)
            UE_Log("The out value is set before " & $outValue )

            stack.increaseStack()
            let obj = cast[UMyClassToTestPtr](context) 
            obj.bWasCalled = true
            type Param = object
                param0 : int32
                param1 : int32

            var params = cast[ptr Param](stack.locals)
            let fn = stack.node
            #actual func
            params.param0 = 5
            params.param1 = 5

          
            var paramVal : int32 = 5

            #end actual func
            #we know here there is only one, but they can be matched by name if when generating the params we use the same name
            #for the uprop. Since emited functions can only be emited by nim, we should be good by doing so.
            
            var currentOut = stack.outParms
            while not currentOut.isNil():
                let propName = currentOut.property.getName()
                let propValue = cast[ptr int32](currentOut.propAddr)[]
                
                # cast[pointer](currentOut.propAddr) = cast[pointer](paramVal.addr)
                UE_Log(fmt("PropName: {$propName} PropValue:{$propValue} PropAddress:{ cast[uint64](currentOut.propAddr.addr) }"))
                currentOut = currentOut.nextOutParm #<-

            let param0Addr = cast[uint64](params.param0.addr)
            let param1Addr = cast[uint64](params.param1.addr)

            UE_Log(fmt("locals addr: {stack.locals.repr}"))
            UE_Log(fmt("Param addr: {params.addr.repr}"))
            UE_Log(fmt("Param0 addr: {param0Addr}"))
            UE_Log(fmt("Param1 addr: {param1Addr}"))

            # let outParamProp = stack.outParms.property
            # let outParamResult = cast[pointer](stack.outParms.propAddr)

            params.param0 = 5
            params.param1 = 5



            # let valBefore : int32 = cast[ptr int32](stack.outParms.propAddr)[]
            # UE_Log("The out param value is set before " & $valBefore )
            # discard memcpy(stack.outParms.propAddr, paramVal.addr, sizeof(int32).int32)
            cast[ptr int32](stack.outParms.propAddr)[] = paramVal
            # let valAfter : int32 = cast[ptr int32](stack.outParms.propAddr)[]
            # UE_Log("The out param value is set after" & $valAfter )

            # # outValue = paramVal
            # setPropertyValuePtr[int32](outParamProp, outValue.addr, paramVal.addr)
            # let outAddr = cast[uint8](outValue.addr)
            # UE_Log("The address is " & $ outAddr)
            # UE_Log("The out value is set after " & $outValue )


        let fnField = UEField(kind:uefFunction, name:"NewFuncOutParams", fnFlags: FUNC_Native or FUNC_HasOutParms, 
                            signature: @[
                                UEField(kind:uefProp, name: "Param1", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm), 
                                UEField(kind:uefProp, name: "Param2", uePropType: "int32", propFlags:CPF_Parm or CPF_OutParm)
                            ]
                    )

        let fn = createUFunctionInClass(cls, fnField, fnImpl)


        proc newFuncOutParams(obj:UMyClassToTestPtr, param:var int32, param2: int32) {.uebind .} 
        type
            Params = object
                param: int32
                param2: int32

        var params = Params(param: 3, param2: 2)
        var fnName: FString = "NewFuncOutParams"
        callUFuncOn(obj, fnName, params.addr)
        
        # obj.newFuncOutParams(param0, param1)

        assert obj.bWasCalled
        assert fn.numParms == 2
        # assert fn.getPropsWithFlags(CPF_OutParm).num() == 1
        assert params.param == 5 #only this one is changed
        # assert params.param2 == 1
        
        #restore things as they were
        cls.removeFunctionFromFunctionMap fn
        cls.Children = fn.Next 
        


        


