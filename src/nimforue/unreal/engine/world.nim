import enginetypes
include ../definitions
import ../core/math/vector
import ../coreuobject/[uobject, coreuobject, nametypes]
import ../nimforue/nimforuebindings
import ../core/[delegates]

#world is defined in uobject, here are the functions related to it

type 
  FActorSpawnParameters* {.importcpp.}= object
    name* {.importcpp: "Name".} : FName
    actorTemplate* {.importcpp: "Template".} : AActor
    owner* {.importcpp: "Owner".} : AActor
    instigator* {.importcpp: "Instigator".} : APawn


# AActor* SpawnActor( UClass* Class, FTransform const* Transform, const FActorSpawnParameters& SpawnParameters = FActorSpawnParameters());

proc spawnActor*(world:UWorldPtr, class: UClassPtr, transform: ptr FTransform, spawnParameters=FActorSpawnParameters()): AActorPtr {.importcpp: "#->SpawnActor(@)".}
proc spawnActor*(world:UWorldPtr, class: UClassPtr, location: ptr FVector, rotation:ptr FRotator, spawnParameters=FActorSpawnParameters()): AActorPtr {.importcpp: "#->SpawnActor(@)".}
proc spawnActor*(world:UWorldPtr, class: UClassPtr, location: FVector, rotation=FRotator(), spawnParameters=FActorSpawnParameters()): AActorPtr =
  spawnActor(world, class, unsafeAddr location, unsafeAddr rotation, spawnParameters)

proc spawnActor*[T : AActor](world:UWorldPtr, location: FVector, rotation=FRotator(), spawnParameters=FActorSpawnParameters()): ptr T =
  let class = staticClass(T)
  spawnActor(world, class, unsafeAddr location, unsafeAddr rotation, spawnParameters).ueCast[:T]()

proc spawnActorWith*[T : AActor](world:UWorldPtr, class:UClassPtr, location: FVector, rotation=FRotator(), spawnParameters=FActorSpawnParameters()): ptr T =
  #useful when you want to use a Nim derived class in bp
  spawnActor(world, class, unsafeAddr location, unsafeAddr rotation, spawnParameters).ueCast[:T]()

proc spawnActorWith*[T : AActor](world:UWorldPtr, class:UClassPtr, transform: FTransform,  spawnParameters=FActorSpawnParameters()): ptr T =
  #useful when you want to use a Nim derived class in bp
  let actor = spawnActor(world, class, unsafeAddr transform, spawnParameters)
  ueCast[T](actor)

proc getGameViewPort*(uworld:UWorldPtr) : UGameViewportClientPtr {. importcpp:"#->GetGameViewport()" .}

# proc getWorldSettings*(uworld: UWorldPtr, bCheckStreamingPersistent = false, bChecked = true): AWorldSettingsPtr {. importcpp:"#->GetWorldSettings(@)" .}
proc notifyBeginPlay*(uworld: AWorldSettingsPtr) {. importcpp:"#->NotifyBeginPlay()" .}
proc notifyMatchStarted*(uworld: AWorldSettingsPtr) {. importcpp:"#->NotifyMatchStarted()" .}

proc tick*(world: UWorldPtr, deltaSecs: float32) {. importcpp:"#->Tick(LEVELTICK_All, #)" .}
proc setShouldTick*(world: UWorldPtr, bShouldTick: bool) {. importcpp:"#->SetShouldTick(#)" .}