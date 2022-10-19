include ../unreal/prelude
import ../unreal/bindings/[engine]
import std/[strformat, sugar, options]




uClass UNimAnimBlueprint of UAnimInstance:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    bTestNim:bool

uClass UItem of UDataAsset:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    icon : UTexturePtr
    name : FString
    description : FString
    mesh : UStaticMeshPtr


uStruct FInventoryItem:
  (BlueprintType)
  uprops():
    item : UItemPtr
    quantity : int

uClass UInventoryComponent of UActorComponent:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    items : TArray[FInventoryItem]
    

  ufuncs(BlueprintCallable):
    proc addItem(item : UItemPtr) = 
      func findItem(it : FInventoryItem) : bool = it.item == item

      if self.items.toSeq().any(findItem):
        let index = toSeq(self.items).firstIndexOf(findItem).int32
        inc self.items[index].quantity
      else:
        self.items = self.items & makeTArray(FInventoryItem(item: item, quantity:1)) 



uClass APickUp of AStaticMeshActor:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    item : UItemPtr

  ufuncs():
    proc userConstructionScript() =
      if self.item.isNotNil() and self.item.mesh.isNotNil():
        discard self.staticMeshComponent.setStaticMesh(self.item.mesh)
      else:
        UE_Warn "No mesh set for pickup"
    
    proc pickUpItem(inventory: UInventoryComponentPtr) {.BlueprintCallable.} =
      inventory.addItem(self.item)
      self.destroyActor()


uClass ANimConfCharacter of ACharacter:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    inventory : UInventoryComponentPtr = initializer.createDefaultSubobject[:UInventoryComponent](n"InventoryComponent")
    initialItems : TArray[UItemPtr] = makeTArray[UItemPtr]()

  ufuncs():  
    proc beginPlay() = 
      for item in self.initialItems:
        self.inventory.addItem(item)

    proc tick(deltaTime:float32) = 
      printString(self, &"Items: {self.inventory.items}", true, false, FLinearColor(r:1.0, g:0.0, b:0.0, a:1.0), 0.0, n"")

  
  ufuncs(CallInEditor):
    proc logAllItems() =
      UE_Log &"Items: {self.inventory.items}"










































      #[
        ufuncs(): 
    proc tick(deltaTime:float32) = 
      printString(self, &"Items: {self.inventory.items}", true, false, FLinearColor(r:1.0, g:0.0, b:0.0, a:1.0), 0.0, n"")

      ]#