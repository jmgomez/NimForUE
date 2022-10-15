include ../unreal/prelude
import ../unreal/bindings/[engine]
import std/[strformat, sugar, options]
#[
  1. Base character (derive from Pawn)
  2. See if there is a way to access the speed.
  3. Base collectible
  4. Inventory Component
  5. 

]#
type ANimForUEDemoCharacter* = object of ACharacter



uStruct FItem:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    icon : UTexturePtr
    name : FString
    description : FString
    mesh : UStaticMeshPtr

uStruct FInventoryItem:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    item : FItem
    quantity : int

uClass UInventoryComponent of UActorComponent:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    items : TArray[FInventoryItem]
    

  ufuncs(BlueprintCallable):
    proc addItem(item : FItem) = 
      func findItem(it : FInventoryItem) : bool = it.item.name == item.name

      if self.items.toSeq().any(findItem):
        let index = toSeq(self.items).firstIndexOf(findItem).int32
        inc self.items[index].quantity
      else:
        self.items = self.items & makeTArray(FInventoryItem(item: item, quantity:1)) 



#Add a delegate?
uClass APickUp of AStaticMeshActor:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    item : FItem
    # sphereCollisionComp : USphereComponentPtr 

  ufuncs():
    proc userConstructionScript() =
      if not self.item.mesh.isNil():
        discard self.staticMeshComponent.setStaticMesh(self.item.mesh)
      else:
        UE_Warn "No mesh set for pickup"
    
    proc pickUpItem(inventory: UInventoryComponentPtr) {.BlueprintCallable.} =
      inventory.addItem(self.item)
      self.destroyActor()

# proc aPickUpConstructor(self: APickUpPtr, initializer: FObjectInitializer) {.uConstructor.} =
#   self.sphereCollisionComp = initializer.createDefaultSubobject[:USphereComponent](n"SphereCollisionComp")
#   self.sphereCollisionComp.attachToComponent(self.staticMeshComponent)





uClass ANimConfCharacter of ACharacter:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    inventory : UInventoryComponentPtr = initializer.createDefaultSubobject[:UInventoryComponent](n"InventoryComponent")

  ufuncs(BlueprintCallable):
    proc sayHello() = 
      UE_Log "Hello!"

  ufuncs(CallInEditor):
    proc logAllItems() =
      UE_Log &"Items: {self.inventory.items}"