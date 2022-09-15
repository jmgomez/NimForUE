include ../nimforue/unreal/prelude
import ../nimforue/typegen/[models, uemeta]
import ../nimforue/macros/uebind

#access to prelude



const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uetClass, 
                    fields: @[
                        UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                     
                        makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)], "UMyClassToTest"),
                        makeFieldAsUFun("GetHelloWorldStatic", @[makeFieldAsUPropParam("Par", "FString", CPF_ReturnParm or CPF_Parm)],"UMyClassToTest", FUNC_Static),
                        ])

genType(uePropType)



proc fakeExporter() : UMyClassToTestPtr  {.exportcpp.} = cast[UMyClassToTestPtr](nil)

proc getHelloWorld2*(obj : UMyClassToTestPtr) : FString {.exportcpp, thiscall.} =
  obj.getHelloWorld()



proc getNameFromCpp*(obj : UMyClassToTestPtr) : FString {.exportcpp, thiscall.} = obj.getName() #& "append something from cpp "
