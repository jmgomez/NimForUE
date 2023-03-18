include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate]
import ../vm/[uecall]

import vminteroppocexample




#[
  No return, no args first
    [x] Try to replace an existing function add hoc, like picking another and calling that one instead.
    [x] Try to replace an existing function with a new one 

  -- 

    [ ] Try to replace an existing function from the VM manually (it will require interop etc.)



]#
var replacementForSaluteImpl : UFunctionNativeSignature = proc (context: UObjectPtr; stack: var FFrame; returnResult: pointer) : void {.cdecl.} =
  stack.increaseStack()
  # let self = ueCast[AUEBorrowTestActor](context)
  UE_Log "You have been replaced!"



uClass AUEBorrowTestActor of AActor:
  (BlueprintType)
  ufunc:
    proc replacementSalute() = 
        UE_Log "Hola from UObjectPOC instanceFunc. The function was REPLACED!"

  ufuncs(CallInEditor):
    proc callSalute() = 
      salute()
    proc replaceAdHoc() = 
      let saluteFn = staticClass(UObjectPOC).getFuncsFromClass.first(fn => fn.getName()  == "Salute")
      for fn in staticClass(UObjectPOC).getFuncsFromClass():
        UE_Log "Found function: " & fn.getName()
        # fn.setNativeFunc(replacementSalute)

      UE_Log "Salute function is: " & $saluteFn
      if saluteFn.isSome:
        saluteFn.get.setNativeFunc((cast[FNativeFuncPtr](replacementForSaluteImpl)))
