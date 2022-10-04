include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore, engine]
# import ../unreal/bindings/exported/[slate, slatecore]
# import ../unreal/bindings/exported/nimforue
import ../typegen/[uemeta]
import std/random


const testActorUEType = UEType(name: "ATestActor", parent: "AActor", kind: uetClass, 
                  fields: @[
                 
                      ])
genType(testActorUEType)



#This is temp
proc getCurrentActiveWorld() : UWorldPtr {.importcpp:"UReflectionHelpers::GetCurrentActiveWorld()", header:ueIncludes.}

proc getOwner2*(obj : UActorComponentPtr): AActorPtr {.importcpp: "#->GetOwner()", header: ueIncludes.}

uClass UNimActorComponentTest of UActorComponent:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    componentProp : FString
  
  ufuncs(BlueprintCallable):
    proc testFunc2() = 
      UE_Log "Test function 2 called"
      UE_Log $self
      # findObject[UPackage](nil, convertToLongScriptPackageName(packageName))
      # UE_Log $self.getOwner()
      let name = "BP_StaticMeshActor_C_1"
      # let actor = findObject[UObject](nil, name)
      let actor = self.getOwner2()
      UE_Log $actor
      UE_Log $actor.isNil()
      UE_Log "Ends testfunc"

      let world = getCurrentActiveWorld()
      UE_Log $world
      # UE_Log $world.isNil()


# Begin Map
#    Begin Level
#       Begin Actor Class=/Game/LevelPrototyping/BP_StaticMeshActor.BP_StaticMeshActor_C Name=BP_StaticMeshActor_C_1 Archetype=/Game/LevelPrototyping/BP_StaticMeshActor.BP_StaticMeshActor_C'/Game/LevelPrototyping/BP_StaticMeshActor.Default__BP_StaticMeshActor_C'
#          Begin Object Class=/Script/Engine.StaticMeshComponent Name="StaticMeshComponent0" Archetype=StaticMeshComponent'/Game/LevelPrototyping/BP_StaticMeshActor.Default__BP_StaticMeshActor_C:StaticMeshComponent0'
#          End Object
#          Begin Object Class=/Game/LevelPrototyping/BP_NimActorComponent.BP_NimActorComponent_C Name="BP_NimActorComponent" Archetype=BP_NimActorComponent_C'/Game/LevelPrototyping/BP_StaticMeshActor.BP_StaticMeshActor_C:BP_NimActorComponent_GEN_VARIABLE'
#          End Object
#          Begin Object Name="StaticMeshComponent0"
#             StaticMeshImportVersion=1
#             RelativeLocation=(X=-760.000000,Y=-900.000000,Z=1000.000000)
#          End Object
#          Begin Object Name="BP_NimActorComponent"
#             UCSSerializationIndex=0
#             bNetAddressable=True
#             CreationMethod=SimpleConstructionScript
#          End Object
#          BP_NimActorComponent="BP_NimActorComponent"
#          StaticMeshComponent="StaticMeshComponent0"
#          bCanBeInCluster=False
#          RootComponent="StaticMeshComponent0"
#          ActorLabel="BP_StaticMeshActor"
#       End Actor
#    End Level
# Begin Surface
# End Surface
# End Map



uClass AObjectEngineExample of ATestActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    another : FTextBlockStyle
    nimStaticMesh : UStaticMeshComponentPtr = initializer.createDefaultSubobject[:UStaticMeshComponent](n"NimTestComponent")
    c: FSlateColor
    lc: FLinearColor

    childComp : UChildActorComponentPtr = initializer.createDefaultSubobject[:UChildActorComponent](n"ChildComp")

  ufuncs(BlueprintCallable):
    proc userConstructionScript() =
      UE_Log "This works"

    # proc tick() = 
    #   if self.isNil() or self.nimStaticMesh.isNil():
    #     return
    #   self.nimStaticMesh.relativeLocation = (self.nimStaticMesh.relativeLocation + makeFVector(0, 0, 1))


  ufuncs(CallInEditor):
    proc resetRelativeLocation() = 
      let prev : FVector = self.k2_GetActorLocation()
      try:
        let actor : AActorPtr = self.childComp.getOwner2()
        var hit : FHitResult
        discard actor.k2_SetActorLocation(makeFVector(0, 0, 100), false, hit, true )
      except:
        UE_Error "A problem ocurred "

        discard
      
  #   proc moveStaticMesh() = 
  #     self.nimStaticMesh.relativeLocation =  makeFVector(0, 0, 100) +  self.nimStaticMesh.relativeLocation

  #   proc getAllActors() = 
  #     # let world = self.getWorld()
  #     # if world.isNil():
  #     #   UE_Error "World is nil"
  #     #   return
      
  #     var actors : TArray[AActorPtr]
  #     self.getAllActorsOfClass(makeTSubclassOf[AActor](getClassByName("Actor")), actors)
  #     UE_Log $actors
  #     # UE_Log $self.getWorld()

  #   proc testTextBlockStyle() = 
  #     var testStr = self.another
  #     testStr.shadowOffset = FVector2D(x:100, y:12)
  #     self.another = FTextBlockStyle(shadowOffset: testStr.shadowOffset)
  #     UE_Log "Slate struct"
  #     UE_Log $self.another 
  #     UE_Log $self.another.shadowOffset
    
  #   proc testResetSlateColor() =
  #     self.c = FSlateColor(specifiedColor: FLinearColor(r: 0.1f, g:0.9f, b:0.8f, a: 1.0f))
  #   proc testSlateColor() =
  #     self.lc = FLinearColor(r: 0.5f, g: 0.6f, b:0.7f, a:1.0f)
  #     self.c = FSlateColor(specifiedColor: FLinearColor(r: self.c.specifiedColor.r + 0.1f, g:0.9f, b:0.8f, a: 1.0f))
    
  #   proc testUButtonWidgeStyle() =
  #     let style = newUObject[UButtonWidgetStyle]()
  #     UE_Log $style