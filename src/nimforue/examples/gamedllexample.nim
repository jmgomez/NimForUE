include ../unreal/prelude
import ../../buildscripts/nimforueconfig

import std/[os, dynlib]

let config = getNimForUEConfig()
let dllDir = parentDir config.nimForUELibPath
#Need to add the dir to the library


uClass AGameDllTest of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc testFunc() = 

      UE_Log "Test working!"
      UE_Log dllDir