include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter, nuemacrocache]
import unreal/nimforue/nimforuebindings

import engine/common
import engine/gameframework
import engine/engine
import enhancedinput/enhancedinput
import std/[typetraits, options, asyncdispatch, strformat, tables]

proc tryGetSubsystem*[T: UEngineSubsystem](): Option[ptr T] = 
    tryUECast[T](getEngineSubsystem(makeTSubclassOf[UEngineSubsystem](staticClass[T]())))

proc tryGetSubsystem*[T : USubsystem](objContext: UObjectPtr) : Option[ptr T] =
  let cls = staticClass[T]()
  if cls.isChildOf(staticClass[UGameInstanceSubsystem]()):
    tryUECast[T](getGameInstanceSubsystem(objContext, makeTSubclassOf[UGameInstanceSubsystem](cls)))
  elif cls.isChildOf(staticClass[ULocalPlayerSubsystem]()):
    tryUECast[T](getLocalPlayerSubsystem(objContext, makeTSubclassOf[ULocalPlayerSubsystem](cls)))
  elif cls.isChildOf(staticClass[UWorldSubsystem]()):
    tryUECast[T](getWorldSubsystem(objContext, makeTSubclassOf[UWorldSubsystem](cls)))
  else:
    none[ptr T]()

proc getSubsystem*[T: UEngineSubsystem](): ptr T = tryGetSubsystem[T]().get(nil)
proc getSubsystem*[T: USubsystem](objContext: UObjectPtr): ptr T = tryGetSubsystem[T](objContext).get(nil)


proc drawDebugBox*(context: UObjectPtr, box: FBox, color: FLinearColor, location: FVector, rotation: FRotator, duration: float32) =
  var center, extends: FVector
  getCenterAndExtents(box, center, extends)
  center = center + location
  drawDebugBox(context, center, extends, color, rotation, duration)




proc tickPoll(deltaTime:float32) : bool {.cdecl.} =
  try:      
    poll(0)
  except: 
    discard
  true


proc subscribeToTick() : FTickerDelegateHandle = 
  UE_Log "Subscribed to tick"
  let tickerDel : FTickerDelegate = createStatic[bool, float32](tickPoll)
  let handle = (getCoreTicker()[]).addTicker(tickerDel, 0)
  handle

let tickHandle = subscribeToTick()

when WithEditor:
  import ../../buildscripts/buildscripts
  import std/[os, sequtils, sugar, dynlib]


proc reinstanceFromGloabalEmitter*(globalEmitter:UEEmitterPtr) {.cdecl, exportc.} = 
  when WithEditor:
    proc emitTypesInGuest(calledFrom:NueLoadedFrom, globalEmitter:UEEmitterPtr) = 
          type 
            EmitTypesExternal = proc (emitter : UEEmitterPtr, loadedFrom: NueLoadedFrom, reuseHotReload: bool) {.gcsafe, cdecl.}
          let libDir = PluginDir / "Binaries"/"nim"/"ue"
          let guestPath = getLastLibPath(libDir, "nimforue")
          if guestPath.isNone():
            UE_Error "Could not find guest lib"
            return
          UE_Log "emit types in guest"
          let lib = loadLib(guestPath.get())
          let emitTypesExternal = cast[EmitTypesExternal](lib.symAddr("emitTypesExternal"))
          if emitTypesExternal.isNotNil():
            emitTypesExternal(globalEmitter, calledFrom, reuseHotReload=true)
    emitTypesInGuest(nlfEditor, globalEmitter)

proc isThereAnyNimClass(): bool = 
  var objIter = makeFRawObjectIterator()
  for objIter in objIter:
    if objIter.isValid:
      let cls = objIter.get.ueCast(UClass)      
      if cls.isNotNil and cls.isNimClass():
        return true
  return false

proc reinstanceNextFrame() {.cdecl, exportc.} = 
  when WithEditor:
    sleepAsync(100).callback= () => reinstanceFromGloabalEmitter(getGlobalEmitter())

#Called from the non editor build on StartupModule
proc startNue*() {.cdecl, exportc.} =
  discard emitUStructsForPackage(getGlobalEmitter(), "GameNim", nlfDefault) 
  if withEditorRuntime():
    #We need to emit again to workaround an issue that only happens in editor with custom delegates
    discard onAllModuleLoadingPhasesComplete.addStatic( 
      proc(){.cdecl.} = 
        discard emitUStructsForPackage(getGlobalEmitter(), "GameNim", nlfEditor)         
    )
proc netSerialize*(vec: FVector, ar: var FArchive, map: UPackageMapPtr, bOutSuccess: var bool) {.importcpp:"#.NetSerialize(@)".}

proc getComponent*[C: UActorComponent](actor: AActorPtr, T: typedesc[C]): ptr T {.inline.} = 
  ###usage example: self.getCharacter.getComponent(UAbilitySystemComponent)
  actor.getComponentByClass(T.subClass).ueCast(T)
  

#Textures
proc getResource*(texture: UTexturePtr): ptr FTextureResource {.importcpp:"#->GetResource(@)".}
