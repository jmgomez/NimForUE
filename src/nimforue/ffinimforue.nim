

include unreal/prelude
import unreal/editor/editor
import unreal/core/containers/containers
import ../nimforue/codegen/[ffi,emitter, genreflectiondatav2, models, uemeta, ueemit, umacros]
import std/[options, strformat, dynlib, os, osproc, tables, asyncdispatch, times, json, jsonutils]
import ../buildscripts/[nimforueconfig, buildscripts, keyboard]
import unreal/nimforue/nimforuebindings

const withEngineBindings = fileExists(BindingsImportedDir/"engine"/"engine.nim")
# when withEngineBindings:
#   import unreal/bindings/imported/assetregistry

const genFilePath* {.strdefine.} : string = ""

var prevGameLib : Option[string]

type 
  NueLib = object
    handle: LibHandle
    libName: string
    libPath: string
    timesReloaded: int


proc getEmitterFromGame(nueLib: NueLib): Option[UEEmitterPtr] = 
  type 
    GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, cdecl.}
    MainFn = proc(): void {.gcsafe, cdecl.}
  if nueLib.handle.isNil:
    UE_Error &"Cant load lib {nueLib.libPath}. \r\n File {nueLib.libPath} exits: {fileExists(nueLib.libPath)}"
    return none(UEEmitterPtr)
  let fnPtr = nueLib.handle.symAddr("getGlobalEmitterPtr")
  if fnPtr.isNil:
    UE_Error &"getGlobalEmitterPtr is not in the lib {nueLib.libPath}"
    return none(UEEmitterPtr)
  
  let getEmitter = cast[GetUEEmitterFn](fnPtr)
  let emitterPtr = getEmitter()
  if emitterPtr.isNil():
    UE_Error "Emitter is nil"
  assert not emitterPtr.isNil()
  some emitterPtr


proc startNue(libPath:string, calledFrom:NueLoadedFrom)  = 
  type 
    StartNueFN = proc ( calledFrom:NueLoadedFrom):void {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let startNueFn = cast[StartNueFN](lib.symAddr("startNue"))
  
  assert startNueFn.isNotNil()

  startNueFn(calledFrom)




#Will be called from the commandlet that generates the bindigns
proc genBindingsEntryPoint() : void {.ffi:genFilePath} = 
  try:
    if isRunningCommandlet(): #TODO test not cooking
      generateProject()       
  except:
    UE_Error &"Error in genBindingsEntryPoint: {getCurrentExceptionMsg()}"
    sleep(3000)
     


proc compileBps(emitter:UEEmitterPtr) = 
  var classPaths = makeTArray[FTopLevelAssetPath]()
  for e in emitter[].emitters.values:
    let uet = e.ueType
    if uet.kind != uetClass or CompileBPMetadataKey notin uet.metadata: continue    
    let cls = getClassByName(uet.name.removeFirstLetter())  
    let assetPath = cls.getClassPathName()
    classPaths.add(assetPath)

  var farFilter = FARFilter(bRecursiveClasses: true, classPaths: classPaths)
  var assets: TArray[FAssetData]
  
  # when withEngineBindings:
  #   if classPaths.len > 0:
  #     getBlueprintAssets(farFilter, assets)
  #   else: UE_Log "No compileBps assets found"

  for asset in assets:
    let path = asset.objectPath
    let bp = loadObject[UBlueprint](nil, path.toFString())
    if bp.isNotNil: 
      UE_Log &"Compiling blueprint {bp.getName()}"
      # bp.compileBlueprint()

proc emitNueTypes*(emitter: UEEmitterPtr, packageName:string, emitEarlyLoadTypesOnly, reuseHotReload:bool) : bool = 
    try:
        log "Emitting types for package: " & packageName
        let nimHotReload = emitUStructsForPackage(emitter, packageName, emitEarlyLoadTypesOnly)
        if not nimHotReload.bShouldHotReload:
          UE_Log "Nothing to re/instance"
          return false
        #For now we assume is fine to EmitUStructs even in PIE. IF this is not the case, we need to extract the logic from the FnNativePtrs and constructor so we can update them anyways
        if GEditor.isNotNil() and not GEditor.isInPIE():#Not sure if we should do it only for non guest targets
          reinstanceNueTypes(packageName, nimHotReload, "", reuseHotReload)
          compileBps(emitter)
          return;
       
        proc onPIEEndCallback(isSimulating:bool, packageName:string, hotReload:FNimHotReloadPtr, handle:FDelegateHandlePtr, emitter: UEEmitterPtr) {.cdecl.} = 
          reinstanceNueTypes(packageName, hotReload, "", false)
          compileBps(emitter)
          onEndPIEEvent.remove(handle[])
          deleteCpp(handle)
          UE_LOG(&"NimUE: PIE ended, reinstanciated nue types {packageName}")



        let onPIEEndHandle = newCpp[FDelegateHandle]()
        (onPIEEndHandle[]) = onEndPIEEvent.addStatic(onPIEEndCallback, packageName, nimHotReload, onPIEEndHandle, emitter)
        UE_Log "Deffered reinstance of NueTypes for package: " & packageName & " after PIE ended"
        return nimHotReload.bShouldHotReload
       
    except Exception as e:
        #TODO here we could send a message to the user
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()
        return false

proc emitTypeFor(nueLib: NueLib, loadedFrom : NueLoadedFrom) = 
  if isRunningCommandlet(): 
    UE_Log "Running command let, dont emit types"
    return
  try:
    UE_Log &"Emitting types for {nueLib.libName}"
    let earlyLoad = false
    case nueLib.libName:
    of "nimforue": 
        discard emitNueTypes(getGlobalEmitter(), "Nim", earlyLoad, false)
        # if not isRunningCommandlet() and timesReloaded == 0: 
          # genBindingsCMD()
          # discard   
    else:
      if not isRunningCommandlet():
        let gameEmitter = nueLib.getEmitterFromGame()
        if gameEmitter.isSome:
          discard emitNueTypes(gameEmitter.get, "GameNim", earlyLoad, false)
        else:
          #TODO we should wait and retry to deal with EarlyTypes
          UE_Warn "GameEmitter is nil. Library not loaded yet?"
  except CatchableError as e:
    UE_Error &"Error in onLibLoaded: {e.msg} {e.getStackTrace}"


import std/sugar
#VM manager tests
# proc reloadScript() {.uebindStatic:"UNimVmManager".} #any library that pulls nimvm will have it

proc reloadScriptGuest() {.ffi:genFilePath.} = 
  # return  
  discard callStaticUFunction("NimVmManager", "ReloadScript", nil)  


proc tickPoll(deltaTime:float32) : bool {.cdecl.} =
  try:  
    let p = getGlobalDispatcher()
    poll(0)
  except: 
    discard
  true
#TODO extract so another file and remove handler
proc subscribeToTick() : FTickerDelegateHandle =   
  let tickerDel : FTickerDelegate = createStatic[bool, float32](tickPoll)
  let handle = (getCoreTicker()[]).addTicker(tickerDel, 0)
  handle


var lastTimeTriggered = now()
#only GameNim types 
proc emitTypesExternal(emitter : UEEmitterPtr, loadedFrom:NueLoadedFrom, reuseHotReload: bool) {.cdecl, exportc, dynlib.} = 
  UE_Log "Emitting types from external lib " & $emitter.emitters.len
  let didHotReload = emitNueTypes(emitter, "GameNim",  false, reuseHotReload)
  # if not didHotReload: return #TODO review why is not working as expected (will avoid double lc when no reinstancing)
  let tickHandle = subscribeToTick()
  proc waitForLiveCoding() : Future[void] {.async.} =
    if (now() - lastTimeTriggered).inSeconds < 1:
      return
    #we need to wait a bit so it does something
    await sleepAsync(10) 
    UE_Log "Triggering now"
    triggerLiveCoding(50)
    removeTicker(tickHandle)
    lastTimeTriggered = now()
  asyncCheck waitForLiveCoding()


var libsToEmmit : seq[NueLib] 
proc onLibLoaded(libName:cstring, libPath:cstring, timesReloaded:cint, loadedFrom:NueLoadedFrom, handle: LibHandle) : void {.ffi:genFilePath} = 
  UE_Log &"lib loaded: {libName} loaded from {loadedFrom}. Handle valid: {handle.isNotNil}" 
  var nueLib = NueLib(
    libName: $libName, 
    libPath: $libPath, 
    timesReloaded: timesReloaded,
    handle: handle
  )  
  emitTypeFor(nueLib, loadedFrom)
    

proc onLoadingPhaseChanged(prev : NueLoadedFrom, next:NueLoadedFrom) : void {.ffi:genFilePath} = 
  UE_Log &"Loading phase changed: {prev} -> {next}"
  # if prev == nlfPreEngine and next == nlfPostDefault:
  #   for nueLib in libsToEmmit:
  #     UE_Log &"Emitting types for {nueLib.libName} "
  #     emitTypeFor(nueLib, next)
  


# uEnum EEnumGuestSomethingElse: 
#   (BlueprintType)
#   Value1
#   Value2
#   Value3
#   Value4
#   Value5

# uEnum EMyEnumCreatedInDsl:
#     (BlueprintType)
#     WhateverEnumValue
#     SomethingElse

uClass ANimTestGuest of AActor:
  uprops(EditAnywhere, BlueprintReadWrite):
    test: int
    anotehr: FString
    yes: bool
  ufuncs(CallInEditor):
    proc testQueryModules() = 
      # logModules()
      discard

    proc logModelViewViewModelState() = 
      discard
# # VM
# #TODO refactor the vm so emitType is only called once. 
# uClass UVmHelpers of UObject:
#   ufuncs(Static):
#     proc emitType(uetJson: FString) = 
#       let types = uetJson.parseJson.jsonTo(seq[UEType])
#       #emitNueTypes(getGlobalEmitter(), "Nim", loadedFrom == nlfPreEngine, false)
#       let emitter = initEmitter() #TODO deallocate after wards or use a ref and cast it back to a ptr
#       for typeDef in types:
#         var typeDef = typeDef
#         case typeDef.kind:
#         of uetClass:
#           var typeDef = typeDef
#           #last chance to fix the typedef comming from the vm
#           for field in typeDef.fields.mitems:
#             if field.kind != uefFunction: continue
#             if "Static" in field.metadata: 
#               field.fnFlags = field.fnFlags or FUNC_Static



#           #This may cause issues as it is a whole new path. Native uses addEmitterInfoForClass
#           addEmitterInfo(typeDef, (package:UPackagePtr) => emitUClass[void](typeDef, package, @[], vmConstructor, nil), emitter)
#         of uetEnum:         
#           addEmitterInfo(typeDef, (package:UPackagePtr) => emitUEnum(typeDef, package), emitter)
#         of uetStruct:
#           addEmitterInfo(typeDef, (package:UPackagePtr) => emitUStruct[void](typeDef, package), emitter)
#         else: continue
#       # UE_Log $ueTyp
#       discard emitNueTypes(emitter, "GameNim", false, false)
#       compileBps(emitter)
  
