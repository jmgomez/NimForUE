

include unreal/prelude
import unreal/editor/editor
import ../nimforue/codegen/[ffi,emitter, genreflectiondata, models, uemeta]
import std/[options, strformat, dynlib]
import ../buildscripts/[nimforueconfig, buildscripts]

const genFilePath* {.strdefine.} : string = ""




proc getEmitterFromGame(libPath:string) : UEEmitterPtr = 
  type 
    GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let getEmitter = cast[GetUEEmitterFn](lib.symAddr("getUEEmitter"))
  
  assert not getEmitter.isNil()

  let emitterPtr = getEmitter()
  assert not emitterPtr.isNil()
  emitterPtr



proc emitNueTypes*(emitter: UEEmitterRaw, packageName:string) = 
    try:
        let nimHotReload = emitUStructsForPackage(emitter, packageName)
        #For now we assume is fine to EmitUStructs even in PIE. IF this is not the case, we need to extract the logic from the FnNativePtrs and constructor so we can update them anyways
        if not GEditor.isInPIE():#Not sure if we should do it only for non guest targets
          reinstanceNueTypes(packageName, nimHotReload, "")
          return;
       
        proc onPIEEndCallback(isSimulating:bool, packageName:string, hotReload:FNimHotReloadPtr, handle:FDelegateHandlePtr) {.cdecl.} = 
          reinstanceNueTypes(packageName, hotReload, "")
          onEndPIEEvent.remove(handle[])
          deleteCpp(handle)
          UE_LOG(&"NimUE: PIE ended, reinstanciated nue types {packageName}")
          
        let onPIEEndHandle = newCpp[FDelegateHandle]()
        (onPIEEndHandle[]) = onEndPIEEvent.addStatic(onPIEEndCallback, packageName, nimHotReload, onPIEEndHandle)
        UE_Log "Deffered reinstance of NueTypes for package: " & packageName & " after PIE ended"

       
    except Exception as e:
        #TODO here we could send a message to the user
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()




type FTableRowBase* {.importcpp, inheritable, pure .} = object

type FNimTableRowBase* = object of FTableRowBase
  testProperty*: FString

const ueStructType = UEType(name: "FNimTableRowBase", kind: uetStruct, superStruct:"FTableRowBase",
                        metadata: @[makeUEMetadata("BlueprintType")],
                        fields: @[
                            UEField(kind:uefProp, name: "TestProperty", uePropType: "FString"),
                        ])

#entry point for the game. but it will also be for other libs in the future
#even the next guest/nimforue?
proc onLibLoaded(libName:cstring, libPath:cstring, timesReloaded:cint) : void {.ffi:genFilePath} = 
  try:
    case $libName:
    of "nimforue": 
        emitNueTypes(getGlobalEmitter()[], "Nim")
        if timesReloaded == 0: #Generate bindings. The collected part is single threaded ATM, that's one we only do it once. It takes around 2-3 seconds.
          execBindingsGenerationInAnotherThread()

        # let guestPgk = tryGetPackageByName("Nim").get()
        # discard emitUStruct[FNimTableRowBase](ueStructType, guestPgk)                     
    of "game":
        emitNueTypes(getEmitterFromGame($libPath)[], "GameNim")
    
    UE_Log &"lib loaded: {libName}"
  except:
    UE_Error &"Error in onLibLoaded: {getCurrentExceptionMsg()}"



