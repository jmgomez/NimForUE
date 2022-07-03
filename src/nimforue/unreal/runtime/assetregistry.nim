import ../coreuobject/uobject





#static void AssetCreated(UObject* NewAsset)
proc assetCreated*(obj:UObjectPtr) : void {.importcpp:"FAssetRegistryModule::AssetCreated(#)".}