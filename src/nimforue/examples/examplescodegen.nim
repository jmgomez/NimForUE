include ../unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../../codegen/[codegentemplate,genreflectiondata]
import ../macros/genmodule #not sure if it's worth to process this file just for one function? 


#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    delTypeName : FString = "test"
    structPtrName : FString 
  ufuncs(CallInEditor):
    proc genReflectionData() = 
      try:
        execBindingsGenerationInAnotherThread()
        # discard genReflectionData(getAllInstalledPlugins(getNimForUEConfig()))
        # let rulesASJson = moduleRules.toJson().pretty()
        # UE_Log rulesASJson
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"
   
    proc showType() = 
      let obj = getUTypeByName[UDelegateFunction]("UMG.ComboBoxKey:OnOpeningEvent"&DelegateFuncSuffix)
      let obj2 = getUTypeByName[UDelegateFunction]("OnOpeningEvent"&DelegateFuncSuffix)
      UE_Warn $obj
      UE_Warn $obj2
      UE_Warn $obj2


    proc searchDelByName() = 
      let obj = getUTypeByName[UDelegateFunction](self.delTypeName&DelegateFuncSuffix)
      if obj.isNil(): 
        UE_Error &"Error del is null"
        return

      UE_Warn $obj
      UE_Warn $obj.getOuter()
    
    