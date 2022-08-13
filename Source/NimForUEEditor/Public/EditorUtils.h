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

/**
 * 
 */
UCLASS()
class NIMFORUEEDITOR_API UEditorUtils : public UObject {
	GENERATED_BODY()
public:
	UNimReferenceReplacementHelper* ReplaceHelper = nullptr;
	
	static void RefreshNodes();
	static void RefreshNodes(FNimHotReload* NimHotReload);
	static void PerformReinstance(FNimHotReload* NimHotReload);
	void HotReload(FNimHotReload* NimHotReload);
	static void ReloadClass(UClass* OldClass, UClass* NewClass);
	void ReloadClasses(FNimHotReload* NimHotReload);
	void PostReload();
	void PreReload(FNimHotReload* NimHotReload);
	void HotReloadV2(FNimHotReload* NimHotReload);
	static void ShowLoadNotification(bool bIsFirstLoad);

	//
	// static TArray<UDataTable*> GetTablesDependentOnStruct(UStruct* Struct)
	// {
	// 	TArray<UDataTable*> Result;
	// 	if (Struct)
	// 	{
	// 		TArray<UObject*> DataTables;
	// 		GetObjectsOfClass(UDataTable::StaticClass(), DataTables);
	// 		for (UObject* DataTableObj : DataTables)
	// 		{
	// 			UDataTable* DataTable = Cast<UDataTable>(DataTableObj);
	// 			if (DataTable && (Struct == DataTable->RowStruct))
	// 			{
	// 				Result.Add(DataTable);
	// 			}
	// 		}
	// 	}
	// 	return Result;
	// }
};

