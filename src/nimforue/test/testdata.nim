include ../unreal/prelude

const ueEnumType = UEType(name: "EMyTestEnum", kind: uEnum, 
                            fields: @[
                                UEField(kind:uefEnumVal, name:"TestValue"),
                                UEField(kind:uefEnumVal, name:"TestValue2")
                            ]
                        )
genType(ueEnumType)

const ueStructType = UEType(name: "FStructToUseAsVar", kind: uStruct, 
                        fields: @[
                            UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])
genType(ueStructType)                


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
                        UEField(kind:uefProp, name: "ArrayProperty", uePropType: "TArray[FString]", isGeneric:true),
                        UEField(kind:uefProp, name: "ObjectProperty", uePropType: "UClassToUseAsVarPtr"),
                        UEField(kind:uefProp, name: "StructProperty", uePropType: "FStructToUseAsVar"),
                        UEField(kind:uefProp, name: "ClassProperty", uePropType: "UClassPtr"),
                        UEField(kind:uefProp, name: "SubclassOfProperty", uePropType: "TSubclassOf[UObject]", isGeneric:true), 
                        UEField(kind:uefProp, name: "EnumProperty", uePropType: "EMyTestEnum"), 
                        UEField(kind:uefProp, name: "SoftObjectProperty", uePropType: "TSoftObjectPtr[UObject]", isGeneric:true), 
                        UEField(kind:uefProp, name: "MapProperty", uePropType: "TMap[FString, int32]", isGeneric:true, returnAsVar:true), 
                        UEField(kind:uefProp, name: "NameProperty", uePropType: "FName"), 
                        UEField(kind:uefDelegate, name: "DynamicDelegateOneParamProperty", delKind:uedelDynScriptDelegate, delegateSignature: @["FString"]), 
                        UEField(kind:uefDelegate, name: "MulticastDynamicDelegateOneParamProperty", delKind:uedelMulticastDynScriptDelegate, delegateSignature: @["FString"]), 
                        UEField(kind:uefProp, name: "bWasCalled", uePropType: "bool"),
                        ])



genType(ueVarType)
genType(uePropType) #Notice we wont be using genType directly
