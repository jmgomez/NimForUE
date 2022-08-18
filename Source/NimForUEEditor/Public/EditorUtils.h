// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "NimForUEBindings/Public/FNimHotReload.h"
#include "UObject/Object.h"
#include "EditorUtils.generated.h"




UCLASS()
class NIMFORUEEDITOR_API UNimReferenceReplacementHelper : public UObject
{
	GENERATED_BODY()
public:

	static void AddReferencedObjects(UObject* InThis, FReferenceCollector& Collector);
	virtual void Serialize(FStructuredArchive::FRecord Record) override;
};

UCLASS()
class NIMFORUEEDITOR_API UEditorUtils : public UObject {
	GENERATED_BODY()
	TArray<UBlueprint*> BlueprintsWithAssetOpen = {};
	
public:
	UNimReferenceReplacementHelper* ReplaceHelper = nullptr;
	
	static void PerformReinstance(FNimHotReload* NimHotReload);
	TArray<UBlueprint*> GetDependentBlueprints(FNimHotReload* NimHotReload);
	void HotReload(FNimHotReload* NimHotReload, class FReload* UnrealReload);
	static void ReloadClass(UClass* OldClass, UClass* NewClass);
	void ReloadClasses(FNimHotReload* NimHotReload);
	void PostReload();
	void PreReload(FNimHotReload* NimHotReload);
	void HotReloadV2(FNimHotReload* NimHotReload);
	static void ShowLoadNotification(bool bIsFirstLoad);
	//Called by the Subsystem.
	void Tick(float DeltaTime);
	
};

