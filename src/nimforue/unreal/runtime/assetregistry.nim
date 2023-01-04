import ../coreuobject/uobject



type IAssetRegistry* {.importcpp.} = object

#static void AssetCreated(UObject* NewAsset)
proc assetCreated*(obj:UObjectPtr) : void {.importcpp:"FAssetRegistryModule::AssetCreated(#)".}



proc getIAssetRegistry*(): ptr IAssetRegistry {.importcpp:"IAssetRegistry::Get()".}