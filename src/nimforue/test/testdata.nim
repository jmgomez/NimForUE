include ../unreal/prelude
import ../typegen/uemeta
import std/tables
# export typegen/models

const ueEnumType = UEType(name: "EMyTestEnum", kind: uetEnum, 
                            fields: @[
                                UEField(kind:uefEnumVal, name:"TestValue"),
                                UEField(kind:uefEnumVal, name:"TestValue2")
                            ]
                        )
genType(ueEnumType)
const mytable : Table[string, bool] = {"key1": true, "key2": false}.toTable()

const ueStructType = UEType(name: "FStructToUseAsVar", kind: uetStruct,
                        fields: @[
                            UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])
  
genType(ueStructType)

# emitType(ueStructType, ueStructType)

#temp
type
    AActor* = object of UObject
    AActorPtr* = ptr AActor
const ueVarType = UEType(name: "UClassToUseAsVar", parent: "UObject", kind: uetClass, 
                    fields: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])


const dynMulDel = UEType(name: "FDynamicMulticastDelegateOneParamTest", kind: uetDelegate, delKind:uedelMulticastDynScriptDelegate, fields: @[makeFieldAsUPropParam("Par", "FString")])
genType(dynMulDel)

const dynDel = UEType(name: "FDynamicDelegateOneParamTest", kind: uetDelegate, delKind:uedelDynScriptDelegate, fields: @[makeFieldAsUPropParam("Par", "FString")])
genType(dynDel)
const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uetClass, 
                    fields: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        UEField(kind:uefProp, name: "IntProperty", uePropType: "int32"),
                        UEField(kind:uefProp, name: "FloatProperty", uePropType: "float32"),
                        UEField(kind:uefProp, name: "BoolProperty", uePropType: "bool"),
                        UEField(kind:uefProp, name: "ArrayProperty", uePropType: "TArray[FString]"),
                        UEField(kind:uefProp, name: "ObjectProperty", uePropType: "UClassToUseAsVarPtr"),
                        UEField(kind:uefProp, name: "StructProperty", uePropType: "FStructToUseAsVar"),
                        UEField(kind:uefProp, name: "ClassProperty", uePropType: "UClassPtr"),
                        UEField(kind:uefProp, name: "SubclassOfProperty", uePropType: "TSubclassOf[UObject]"), 
                        UEField(kind:uefProp, name: "EnumProperty", uePropType: "EMyTestEnum"), 
                        UEField(kind:uefProp, name: "SoftObjectProperty", uePropType: "TSoftObjectPtr[UObject]"), 
                        UEField(kind:uefProp, name: "SoftClassProperty", uePropType: "TSoftClassPtr[UObject]"), 
                        UEField(kind:uefProp, name: "MapProperty", uePropType: "TMap[FString, int32]"), 
                        UEField(kind:uefProp, name: "NameProperty", uePropType: "FName"), 
                        makeFieldAsUPropDel("DynamicDelegateOneParamProperty", "FDynamicDelegateOneParamTest"),
                        makeFieldAsUPropMulDel("MulticastDynamicDelegateOneParamProperty", "FDynamicMulticastDelegateOneParamTest"),
                        UEField(kind:uefProp, name: "bWasCalled", uePropType: "bool"),
                        #functions TODO Create in cpp, functions that has out params. and also a mix of all. Also make one with TArray, TMap etc
                        makeFieldAsUFun("BindDelegateFuncToDelegateOneParam", @[], "UMyClassToTest"),
                        makeFieldAsUFun("BindDelegateFuncToMultcasDynOneParam", @[], "UMyClassToTest"),
                        makeFieldAsUFun("DelegateFunc", @[makeFieldAsUPropParam("Par", "FString", CPF_Parm)], "UMyClassToTest"),
                        makeFieldAsUFun("FakeFunc", @[], "UMyClassToTest"),
                        makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)], "UMyClassToTest"),
                        makeFieldAsUFun("GetHelloWorldStatic", @[makeFieldAsUPropParam("Par", "FString", CPF_ReturnParm or CPF_Parm)],"UMyClassToTest", FUNC_Static),
                        ])



genType(ueVarType)
genType(uePropType) #Notice we wont be using genType directly
