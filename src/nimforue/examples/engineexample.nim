include ../unreal/prelude



uClass UObjectExample of UObject:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    # intProp2 : int32