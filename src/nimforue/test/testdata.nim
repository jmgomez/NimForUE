include ../unreal/prelude
import ../typegen/uemeta
import std/tables
# export typegen/models

const ueEnumType = UEType(name: "EMyTestEnum", kind: uEnum, 
                            fields: @[
                                UEField(kind:uefEnumVal, name:"TestValue"),
                                UEField(kind:uefEnumVal, name:"TestValue2")
                            ]
                        )
genType(ueEnumType)
const mytable : Table[string, bool] = {"key1": true, "key2": false}.toTable()

const ueStructType = UEType(name: "FStructToUseAsVar", kind: uStruct,
                        fields: @[
                            UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])
  
genType(ueStructType)

# emitType(ueStructType, ueStructType)

#temp
type
    AActor* = object of UObject
    AActorPtr* = ptr AActor
const ueVarType = UEType(name: "UClassToUseAsVar", parent: "UObject", kind: uClass, 
                    fields: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])
                    
const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass, 
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
                        UEField(kind:uefDelegate, name: "DynamicDelegateOneParamProperty", delKind:uedelDynScriptDelegate, delegateSignature: @["FString"]), 
                        UEField(kind:uefDelegate, name: "MulticastDynamicDelegateOneParamProperty", delKind:uedelMulticastDynScriptDelegate, delegateSignature: @["FString"]), 
                        UEField(kind:uefProp, name: "bWasCalled", uePropType: "bool"),
                        #functions TODO Create in cpp, functions that has out params. and also a mix of all. Also make one with TArray, TMap etc
                        makeFieldAsUFun("BindDelegateFuncToDelegateOneParam", @[]),
                        makeFieldAsUFun("BindDelegateFuncToMultcasDynOneParam", @[]),
                        makeFieldAsUFun("DelegateFunc", @[makeFieldAsUPropParam("Par", "FString", CPF_Parm)]),
                        makeFieldAsUFun("FakeFunc", @[]),
                        makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)]),
                        makeFieldAsUFun("GetHelloWorldStatic", @[makeFieldAsUPropParam("Par", "FString", CPF_ReturnParm or CPF_Parm)], FUNC_Static),
                        ])



genType(ueVarType)
genType(uePropType) #Notice we wont be using genType directly
