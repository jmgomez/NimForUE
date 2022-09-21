include ../nimforue/unreal/prelude
import ../nimforue/typegen/[models, uemeta]
import ../nimforue/macros/uebind

import ../nimforue/unreal/bindings/exported/nimforuebindings
import ../nimforue/unreal/bindings/exported/engine
export nimforuebindings



#[
  Set the file path into bindings/exported/modulename
  Set the import path into bindings/modulename

  Add every module to this file (it will only contain import binding/exportedmodulename) (this can be done manually for now)

  Gather all cpp files and copy them over to guestpch

  Tackle Delegate imports

  Revisit the HEADERS once we have the engine working


  

]#


#this works
# const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uetClass, 
#                     fields: @[
#                         makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)], "UMyClassToTest"),
#                         ])

# genType(uePropType)


# type FTestType {.exportcpp.} = object
#   what : int

# proc getHelloWorldNimCall*(obj: UMyClassToTestPtr): FString {.exportcpp .} = FString()
# proc getHelloWorldNimCallPtr*(obj: UMyClassToTestPtr): FTestType  {.exportcpp .} = FTestType()
# proc getHelloWorldThisCallPtr*(obj: UMyClassToTestPtr): FTestType  {.exportcpp, thiscall.} =FTestType()

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
  var fnName: FString = "GetHelloWorld"\
  callUFuncOn(obj, fnName, param.addr)
  return param.returnValue
  ]#

