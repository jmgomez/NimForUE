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
        let actor : AActorPtr = self.childComp.childActor
        var hit : FHitResult
        discard self.k2_SetActorLocation(makeFVector(0, 0, 100), false, hit, true )
      except:
        UE_Error "A problem ocurred "

        discard
      
    proc moveStaticMesh() = 
      self.nimStaticMesh.relativeLocation =  makeFVector(0, 0, 100) +  self.nimStaticMesh.relativeLocation

    proc getAllActors() = 
      # let world = self.getWorld()
      # if world.isNil():
      #   UE_Error "World is nil"
      #   return
      
      var actors : TArray[AActorPtr]
      self.getAllActorsOfClass(makeTSubclassOf[AActor](getClassByName("Actor")), actors)
      UE_Log $actors
      # UE_Log $self.getWorld()

    proc testTextBlockStyle() = 
      var testStr = self.another
      testStr.shadowOffset = FVector2D(x:100, y:12)
      self.another = FTextBlockStyle(shadowOffset: testStr.shadowOffset)
      UE_Log "Slate struct"
      UE_Log $self.another 
      UE_Log $self.another.shadowOffset
    
    proc testResetSlateColor() =
      self.c = FSlateColor(specifiedColor: FLinearColor(r: 0.1f, g:0.9f, b:0.8f, a: 1.0f))
    proc testSlateColor() =
      self.lc = FLinearColor(r: 0.5f, g: 0.6f, b:0.7f, a:1.0f)
      self.c = FSlateColor(specifiedColor: FLinearColor(r: self.c.specifiedColor.r + 0.1f, g:0.9f, b:0.8f, a: 1.0f))
    
    proc testUButtonWidgeStyle() =
      let style = newUObject[UButtonWidgetStyle]()
      UE_Log $style