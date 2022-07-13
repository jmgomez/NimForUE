#pragma once
#include "Kismet2/ReloadUtilities.h"

class FNimReload : public FReload {

	

	/** Output device for any logging */
	FOutputDevice& Ar;
	/** Type of the active reload */
	EActiveReloadType Type = EActiveReloadType::None;

	/** Prefix applied when renaming objects */
	const TCHAR* Prefix = nullptr;

	/** List of packages affected by the reload */
	TArray<UPackage*> Packages;
	
	/** Map from old function pointer to new function pointer for hot reload. */
	TFunctionRemap FunctionRemap;

	/** Map of the reconstructed CDOs during the reinstancing process */
	TMap<UObject*, UObject*> ReconstructedCDOsMap;

	/** Map from old class to new class.  New class may be null */
	TMap<UClass*, UClass*> ReinstancedClasses;

	/** Map from old struct to new struct.  New struct may be null */
	TMap<UScriptStruct*, UScriptStruct*> ReinstancedStructs;

	/** Map from old enum to new enum.  New enum may be null */
	TMap<UEnum*, UEnum*> ReinstancedEnums;

	/** If true, we have to collect the package list from the context */
	bool bCollectPackages;

	/** If true, send reload complete notification */
	bool bSendReloadComplete = true;

	/** If true, reinstancing is enabled */
	bool bEnableReinstancing = true;
	void ReinstanceClass(UClass* NewClass, UClass* OldClass, const TSet<UObject*>& ReinstancingObjects, TSet<UBlueprint*>& CompiledBlueprints);

	struct FBlueprintUpdateInfo
	{
		TSet<UK2Node*> Nodes;
	};

	int32 NumFunctionsRemapped = 0;
	int32 NumScriptStructsRemapped = 0;
	mutable bool bEnabledMessage = false;
	mutable bool bHasReinstancingOccurred = false;
public:
	FNimReload(EActiveReloadType InType, const TCHAR* InPrefix, const TArray<UPackage*>& InPackages, FOutputDevice& InAr) :
		FReload(InType, InPrefix, InPackages, InAr), Ar(InAr) {
	}
	FNimReload(EActiveReloadType InType, const TCHAR* InPrefix, FOutputDevice& InAr) : FReload(InType, InPrefix, InAr), Ar(InAr) {}
	virtual void Reinstance() override;
};
