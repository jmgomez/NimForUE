include ../nimforue/unreal/prelude
import ../nimforue/typegen/[models, uemeta]
import ../nimforue/macros/uebind

#this works
const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uetClass, 
                    fields: @[
                        makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)], "UMyClassToTest"),
                        ])

genType(uePropType)

#[
# this works
type
  UMyClassToTest* {.exportcpp.} = object of UObject
  UMyClassToTestPtr* = ptr UMyClassToTest

proc getHelloWorld*(obj: UMyClassToTestPtr): FString {.exportcpp, thiscall.} =
  type
    Params = object
      returnValue: FString

  var param = Params()
  var fnName: FString = "GetHelloWorld"
  callUFuncOn(obj, fnName, param.addr)
  return param.returnValue
  ]#