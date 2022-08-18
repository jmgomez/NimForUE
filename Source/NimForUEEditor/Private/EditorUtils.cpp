// Fill out your copyright notice in the Description page of Project Settings.


#include "EditorUtils.h"

#include "BlueprintActionDatabase.h"
#include "BlueprintCompilationManager.h"
#include "BlueprintEditor.h"
#include "ComponentTypeRegistry.h"
#include "FileHelpers.h"
#include "FNimReload.h"
#include "K2Node_Event.h"
#include "K2Node_MacroInstance.h"
#include "KismetCompilerMisc.h"
#include "UPropertyCaller.h"
#include "ActorFactories/ActorFactoryVolume.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Async/Async.h"
#include "Engine/DataTable.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Kismet/GameplayStatics.h"
#include "Kismet/KismetStringLibrary.h"
#include "Kismet2/BlueprintEditorUtils.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "Kismet2/ReloadUtilities.h"
#include "Kismet2/StructureEditorUtils.h"
#include "NimForUEEditor/NimForUEEditor.h"
#include "Serialization/ArchiveReplaceObjectRef.h"
#include "Widgets/Notifications/SNotificationList.h"

#define LOCTEXT_NAMESPACE "FNimForUEEditorModule"






void UNimReferenceReplacementHelper::AddReferencedObjects(UObject* InThis, FReferenceCollector& Collector)
{
	if (InThis->HasAnyFlags(RF_ClassDefaultObject))
		return;
	UAssetEditorSubsystem* SubSystem = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>();

	TArray<UObject*> OpenAssets = SubSystem->GetAllEditedAssets();
	Collector.AddReferencedObjects(OpenAssets);
}

void UNimReferenceReplacementHelper::Serialize(FStructuredArchive::FRecord Record)
{
	UObject::Serialize(Record);
	if (HasAnyFlags(RF_ClassDefaultObject))
		return;

	FArchive& UnderlyingArchive = Record.GetUnderlyingArchive();

	if (UnderlyingArchive.IsObjectReferenceCollector())
	{
		// Workaround to replace references to open assets in the asset editor subsystem.
		// If we don't do this, we will have stale object pointers, because it doesn't GC them.
		UAssetEditorSubsystem* SubSystem = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>();

		TArray<UObject*> OpenAssets = SubSystem->GetAllEditedAssets();
		for (UObject* OriginalAsset : OpenAssets)
		{
			UObject* ReplacedAsset = OriginalAsset;
			UnderlyingArchive << ReplacedAsset;

			if (ReplacedAsset != OriginalAsset)
			{
				auto Editors = SubSystem->FindEditorsForAsset(OriginalAsset);
				for (auto* EditorInstance : Editors)
				{
					SubSystem->NotifyAssetClosed(OriginalAsset, EditorInstance);
					SubSystem->NotifyAssetOpened(ReplacedAsset, EditorInstance);
				}
			}
		}
	}
}



void UEditorUtils::PerformReinstance(FNimHotReload* NimHotReload) {
	TUniquePtr<FReload> Reload(new FReload(EActiveReloadType::HotReload, TEXT(""), *GLog)); //activates hot reload so we pass a check (even though we dont use it)
	// Reload->

	for (const auto& ClassToReinstancePair : NimHotReload->ClassesToReinstance) {
		Reload->NotifyChange(ClassToReinstancePair.Key, ClassToReinstancePair.Value);
	}
	Reload->SetSendReloadCompleteNotification(true);

	Reload->Reinstance();

	
	TArray<UBlueprint*> DependencyBPs;
	TArray<UK2Node*> AllNodes;

	// Go through all blueprints and find any that are using a struct
	// or delegate that we have replaced, and change their pins
	// to point to the new ones instead.
	TMap<UClass*, UClass*> ReloadClasses = NimHotReload->ClassesToReinstance;
	TMap<UScriptStruct*, UScriptStruct*> ReloadStructs = NimHotReload->StructsToReinstance;

		TMap<UObject*, UObject*> ClassReplaceList;
		for (auto& Elem : ReloadClasses)
			ClassReplaceList.Add(Elem.Key, Elem.Value);
		for (auto& Elem : ReloadStructs)
			ClassReplaceList.Add(Elem.Key, Elem.Value);

		auto ReplacePinType = [&](FEdGraphPinType& PinType) -> bool
		{
			if (PinType.PinCategory != UEdGraphSchema_K2::PC_Struct)
				return false;

			UScriptStruct* Struct = Cast<UScriptStruct>(PinType.PinSubCategoryObject.Get());
			if (Struct == nullptr)
				return false;

			UScriptStruct** NewStruct = ReloadStructs.Find(Struct);
			if (NewStruct == nullptr)
				return false;

			PinType.PinSubCategoryObject = *NewStruct;
			return true;
		};

		for (TObjectIterator<UBlueprint> BlueprintIt; BlueprintIt; ++BlueprintIt)
		{
			UBlueprint* BP = *BlueprintIt;

			AllNodes.Reset();
			FBlueprintEditorUtils::GetAllNodesOfClass(BP, AllNodes);

			bool bHasDependency = false;
			for (UK2Node* Node : AllNodes)
			{
				TArray<UStruct*> Dependencies;
				if (Node->HasExternalDependencies(&Dependencies))
				{
					for (UStruct* Struct : Dependencies)
					{
						if (ReloadClasses.Contains((UClass*)Struct))
							bHasDependency = true;
						if (ReloadStructs.Contains((UScriptStruct*)Struct))
							bHasDependency = true;

						if (bHasDependency)
							break;
					}
				}

				for (auto* Pin : Node->Pins)
				{
					bHasDependency |= ReplacePinType(Pin->PinType);
				}

				if (auto* EditableBase = Cast<UK2Node_EditablePinBase>(Node))
				{
					for (auto Desc : EditableBase->UserDefinedPins)
					{
						bHasDependency |= ReplacePinType(Desc->PinType);
					}
				}

				// if (auto* Event = Cast<UK2Node_Event>(Node))
				// {
				// 	if (auto* Function = Cast<UDelegateFunction>(Event->GetTiedSignatureFunction()))
				// 	{
				// 		if (NewDelegates.Contains(Function) || ReloadDelegates.Contains(Function))
				// 		{
				// 			bHasDependency = true;
				// 		}
				// 	}
				// }

				if (auto* MacroInst = Cast<UK2Node_MacroInstance>(Node))
				{
					bHasDependency |= ReplacePinType(MacroInst->ResolvedWildcardType);
				}
			}

			for (auto& Variable : BP->NewVariables)
			{
				bHasDependency |= ReplacePinType(Variable.VarType);
			}

			// Check if the blueprint references any of our replacing classes at all
			FArchiveReplaceObjectRef<UObject> ReplaceObjectArch(BP, ClassReplaceList, false, true, true);
			if (ReplaceObjectArch.GetCount())
				bHasDependency = true;

			if (bHasDependency)
				DependencyBPs.Add(BP);
		}

		for (auto& Struct : ReloadStructs)
		{
			// FStructureEditorUtils::BroadcastPreChange(Struct.Key);

			// // Update struct pointers in DataTable with newly generated replacements.
			// TArray<UDataTable*> Tables = GetTablesDependentOnStruct(Struct.Key);
			// for (UDataTable* Table : Tables)
			// {
			// 	Table->RowStruct = Struct.Value;
			// }
		}



	//
	//

	// Do a full-on garbage collection step to make sure old stuff is gone
	// before we start reinstancing things we no longer need.
	CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);

	// Call into unreal's standard reinstancing system to
	// actually recreate objects using the old classes.
	FBlueprintCompilationManager::ReparentHierarchies(ReloadClasses);

	//
	// for (auto& Elem : ReloadClasses) {
	// 	Elem.Key->ConditionalBeginDestroy();
	// }
	// Do a full-on garbage collection step to make sure old stuff is gone
	// by the time we recompile blueprints below.
	CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);

	// Make sure all blueprints that had dependencies to structs or delegates
	// are now properly recompiled.
	if (DependencyBPs.Num() != 0)
	{
		TSet<UClass*> NewlyCreatedClasses;
		for (auto& Elem : ReloadClasses)
			NewlyCreatedClasses.Add(Elem.Value);
		TSet<UScriptStruct*> NewlyCreatedStructs;
		for (auto& Elem : ReloadStructs)
			NewlyCreatedStructs.Add(Elem.Value);

		// Refresh nodes in blueprint graphs that depend on stuff we've reloaded.
		// If we don't do this then we will get errors until the nodes are manually refreshed!
		auto RefreshRelevantNodesInBP = [&](UBlueprint* BP)
		{
			AllNodes.Reset();
			FBlueprintEditorUtils::GetAllNodesOfClass(BP, AllNodes);

			auto CheckRefresh = [&](FEdGraphPinType& PinType) -> bool
			{
				if (PinType.PinCategory != UEdGraphSchema_K2::PC_Struct)
					return false;

				UScriptStruct* Struct = Cast<UScriptStruct>(PinType.PinSubCategoryObject.Get());
				return NewlyCreatedStructs.Contains(Struct);
			};

			for (UK2Node* Node : AllNodes)
			{
				TArray<UStruct*> Dependencies;
				bool bShouldRefresh = false;

				if (Node->HasExternalDependencies(&Dependencies))
				{
					for (UStruct* Struct : Dependencies)
					{
						if (NewlyCreatedClasses.Contains((UClass*)Struct))
						{
							bShouldRefresh = true;
							break;
						}
						if (NewlyCreatedStructs.Contains((UScriptStruct*)Struct))
						{
							bShouldRefresh = true;
							break;
						}
					}
				}

				if (NewlyCreatedStructs.Num() != 0 && !bShouldRefresh)
				{
					for (auto* Pin : Node->Pins)
					{
						bShouldRefresh |= CheckRefresh(Pin->PinType);
					}
				}

				if (auto* EditableBase = Cast<UK2Node_EditablePinBase>(Node))
				{
					for (auto Desc : EditableBase->UserDefinedPins)
					{
						bShouldRefresh |= CheckRefresh(Desc->PinType);
					}
				}
				//
				// if (auto* Event = Cast<UK2Node_Event>(Node))
				// {
				// 	if (auto* Function = Cast<UDelegateFunction>(Event->GetTiedSignatureFunction()))
				// 	{
				// 		if (NewDelegates.Contains(Function) || ReloadDelegates.Contains(Function))
				// 		{
				// 			bShouldRefresh = true;
				// 		}
				// 	}
				// }

				if (auto* MacroInst = Cast<UK2Node_MacroInstance>(Node))
				{
					bShouldRefresh |= CheckRefresh(MacroInst->ResolvedWildcardType);
				}

				if (bShouldRefresh)
				{
					const UEdGraphSchema* Schema = Node->GetGraph()->GetSchema();
					Schema->ReconstructNode(*Node, true);
				}
			}
		};

		// Trigger a compile of all blueprints that we detected dependencies to our class in
		for (UBlueprint* BP : DependencyBPs)
		{
			RefreshRelevantNodesInBP(BP);
			FBlueprintCompilationManager::QueueForCompilation(BP);
		}

		FBlueprintCompilationManager::FlushCompilationQueueAndReinstance();
	}
	//
	// for (auto& Struct : ReloadStructs)
	// {
	// 	FStructureEditorUtils::BroadcastPostChange(Struct.Value);
	// }

	// We want to force-update all the property editing UI now that we've done this reload.
	//  The easiest way to do that is to send this NotifyCustomizationModuleChanged, since
	//  all this does is a refresh on the UI, but there's no separate 'force refresh'.
	FPropertyEditorModule* PropertyModule = FModuleManager::GetModulePtr<FPropertyEditorModule>("PropertyEditor");
	if (PropertyModule)
		PropertyModule->NotifyCustomizationModuleChanged();

}
void UEditorUtils::Tick(float DeltaTime){
	UAssetEditorSubsystem* AssetEditor = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>();
	for (UBlueprint* Bp : BlueprintsWithAssetOpen) {
		//We need to close an open the editor because some properties of the prev
		//bp changed struct have a reference which has been staled
		//it needs to happen on the next slate tick to take effect
		AssetEditor->OpenEditorForAsset(Bp);
	}
	BlueprintsWithAssetOpen = {};
}
void UEditorUtils::HotReload(FNimHotReload* NimHotReload, FReload* UnrealReload) {

	PreReload(NimHotReload);
	UAssetEditorSubsystem* AssetEditor = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>();
	//Refresh nodes first, so we can set the proper blueprint)
	TArray<UBlueprint*> Blueprints = this->GetDependentBlueprints(NimHotReload);
	BlueprintsWithAssetOpen = Blueprints;
	for(auto Bp : Blueprints){
		UE_LOG(LogTemp, Log, TEXT("Blueprint Dependent name is %s"), *Bp->GetName());
		TArray<UStruct*> GenClasses = { Bp->GeneratedClass, Bp->SkeletonGeneratedClass };
		for (UStruct* GenClass : GenClasses) {
			for (TFieldIterator<FProperty> FPropIt = TFieldIterator<FProperty>(GenClass); FPropIt; ++FPropIt) {
				if (FStructProperty* StructProperty = CastField<FStructProperty>(*FPropIt))	{
					TMap<UScriptStruct*, UScriptStruct*> ToUpdateInBp = {};
					for (const auto& StructToReinstancePair : NimHotReload->StructsToReinstance) {
						if (StructProperty->Struct == StructToReinstancePair.Key) {
							StructProperty->Struct = StructToReinstancePair.Value;

							UE_LOG(NimForUEEditor, Warning, TEXT("Blueprint %s replaced type %s with %s "), *Bp->GetName(), *StructToReinstancePair.Key->GetName(), *StructToReinstancePair.Value->GetName());
							//Clean all FProps
							ToUpdateInBp.Add(StructToReinstancePair);

						}
					}
		
				}

			}

		}
		

		FBlueprintEditorUtils::RefreshVariables(Bp);
		//Need to temp close the editor so the FProps are unlinked from slate (see comment on tick)
		AssetEditor->CloseAllEditorsForAsset(Bp);

		Bp->GeneratedClass->Bind();
		Bp->GeneratedClass->StaticLink(true);

		
		
	}
	// FNimReload* Reload(new FNimReload(EActiveReloadType::HotReload, TEXT(""), *GLog));
	// FReload* Reload(new FReload(EActiveReloadType::HotReload, TEXT(""), *GLog));
	for (const auto& ClassToReinstancePair : NimHotReload->ClassesToReinstance)
		UnrealReload->NotifyChange(ClassToReinstancePair.Value, ClassToReinstancePair.Key);
	
	for (const auto& StructToReinstancePair : NimHotReload->StructsToReinstance)
		UnrealReload->NotifyChange(StructToReinstancePair.Value, StructToReinstancePair.Key);

	for (const auto& EnumToReinstancePair: NimHotReload->EnumsToReinstance)
		UnrealReload->NotifyChange(EnumToReinstancePair.Value, EnumToReinstancePair.Key);
		
	
	UnrealReload->Reinstance();
	UnrealReload->Finalize(true);
	UnrealReload->SetSendReloadCompleteNotification(true);


	//Delete prev Structs
	for (const auto& StructToReinstancePair : NimHotReload->StructsToReinstance){
		StructToReinstancePair.Key->ChildProperties = nullptr;
		StructToReinstancePair.Key->ConditionalBeginDestroy();
	}

}

void UEditorUtils::ReloadClass(UClass* OldClass, UClass* NewClass) {
	
	if (OldClass != nullptr)
	{
		if (GEngine != nullptr)
		{
			auto& Database = FBlueprintActionDatabase::Get();
			Database.RefreshClassActions(OldClass);
		}
	}

	if (NewClass != nullptr)
	{
		if (GEngine != nullptr)
		{
			auto& Database = FBlueprintActionDatabase::Get();
			Database.RefreshClassActions(NewClass);
		}

		if (NewClass->IsChildOf(UActorComponent::StaticClass()))
			FComponentTypeRegistry::Get().InvalidateClass(NewClass);
	}
}

void UEditorUtils::ReloadClasses(FNimHotReload* NimHotReload) {
	for(UClass* NewCls : NimHotReload->NewClasses)
		ReloadClass(nullptr, NewCls);
	for(UClass* OldCls : NimHotReload->DeletedClasses)
		ReloadClass(OldCls, nullptr);
	for (auto& Elem : NimHotReload->ClassesToReinstance) {
		ReloadClass(Elem.Key, Elem.Value);
	}
}


void UEditorUtils::PostReload() {

	// We want to force-update all the property editing UI now that we've done this reload.
	//  The easiest way to do that is to send this NotifyCustomizationModuleChanged, since
	//  all this does is a refresh on the UI, but there's no separate 'force refresh'.
	FPropertyEditorModule* PropertyModule = FModuleManager::GetModulePtr<FPropertyEditorModule>("PropertyEditor");
	if (PropertyModule)
		PropertyModule->NotifyCustomizationModuleChanged();
	if(GEngine == nullptr) return;
	// Refresh action list in blueprint, this is what
	// is used to populate the right click menu.
	auto& Database = FBlueprintActionDatabase::Get();
	Database.RefreshAll();


	// Refresh class lists by pretending we just compiled a bp
	GEditor->BroadcastBlueprintCompiled();	
	

	// static bool bInitialCompile = true;
	// if (bInitialCompile)
	// {
	// 	FComponentTypeRegistry::Get().InvalidateClass(nullptr);
	// 	bInitialCompile = false;
	// }

	// If we reloaded any volume classes, trigger a geometry rebuild
	auto* World = GEditor->GetEditorWorldContext().World();
	GEngine->Exec( World, TEXT("MAP REBUILD ALLVISIBLE") );


	
}

void UEditorUtils::PreReload(FNimHotReload* NimHotReload) {
	ReloadClasses(NimHotReload);
	// Init our replace helper that ReparentHierarchies will try to replace stuff in later
	if (ReplaceHelper == nullptr)
	{
		ReplaceHelper = NewObject<UNimReferenceReplacementHelper>(GetTransientPackage());
		ReplaceHelper->AddToRoot();
	}

}

TArray<UBlueprint*> UEditorUtils::GetDependentBlueprints(FNimHotReload* NimHotReload) {
	TMap<UScriptStruct*, UScriptStruct*> ReloadStructs = NimHotReload->StructsToReinstance;
	TMap<UClass*, UClass*> ReloadClasses = NimHotReload->ClassesToReinstance;	

	TArray<UBlueprint*> DependencyBPs;
	TArray<UK2Node*> AllNodes;
	// Go through all blueprints and find any that are using a struct
	// or delegate that we have replaced, and change their pins
	// to point to the new ones instead.
	
	TMap<UObject*, UObject*> ClassReplaceList;
	for (auto& Elem : ReloadClasses)
		ClassReplaceList.Add(Elem.Key, Elem.Value);
	for (auto& Elem : ReloadStructs)
		ClassReplaceList.Add(Elem.Key, Elem.Value);

	auto ReplacePinType = [&](FEdGraphPinType& PinType) -> bool
	{
		if (PinType.PinCategory != UEdGraphSchema_K2::PC_Struct)
			return false;

		UScriptStruct* Struct = Cast<UScriptStruct>(PinType.PinSubCategoryObject.Get());
		if (Struct == nullptr)
			return false;

		UScriptStruct** NewStruct = ReloadStructs.Find(Struct);
		if (NewStruct == nullptr)
			return false;

		PinType.PinSubCategoryObject = *NewStruct;
		return true;
	};

	for (TObjectIterator<UBlueprint> BlueprintIt; BlueprintIt; ++BlueprintIt)
	{
		UBlueprint* BP = *BlueprintIt;

		AllNodes.Reset();
		FBlueprintEditorUtils::GetAllNodesOfClass(BP, AllNodes);

		bool bHasDependency = false;
		for (UK2Node* Node : AllNodes)
		{
			TArray<UStruct*> Dependencies;
			if (Node->HasExternalDependencies(&Dependencies))
			{
				for (UStruct* Struct : Dependencies)
				{
					if (ReloadClasses.Contains((UClass*)Struct))
						bHasDependency = true;
					if (ReloadStructs.Contains((UScriptStruct*)Struct))
						bHasDependency = true;

					if (bHasDependency)
						break;
				}
			}

			for (auto* Pin : Node->Pins)
			{
				bHasDependency |= ReplacePinType(Pin->PinType);
			}

			if (auto* EditableBase = Cast<UK2Node_EditablePinBase>(Node))
			{
				for (auto Desc : EditableBase->UserDefinedPins)
				{
					bHasDependency |= ReplacePinType(Desc->PinType);
				}
			}
			// TODO GetTiedSignatureFunction needs to be reimplemented or rething. They modified the engine to get it
			// if (auto* Event = Cast<UK2Node_Event>(Node))
			// {
			// 	if (auto* Function = Cast<UDelegateFunction>(Event->GetTiedSignatureFunction()))
			// 	{
			// 		if (NimHotReload->NewDelegateFunctions.Contains(Function) || NimHotReload->DelegatesToReinstance.Contains(Function))
			// 		{
			// 			bHasDependency = true;
			// 		}
			// 	}
			// // }

			if (auto* MacroInst = Cast<UK2Node_MacroInstance>(Node))
			{
				bHasDependency |= ReplacePinType(MacroInst->ResolvedWildcardType);
			}
		}

		for (auto& Variable : BP->NewVariables)
		{
			bHasDependency |= ReplacePinType(Variable.VarType);
		}

		// Check if the blueprint references any of our replacing classes at all
		FArchiveReplaceObjectRef<UObject> ReplaceObjectArch(
			BP, ClassReplaceList,
			EArchiveReplaceObjectFlags::IgnoreOuterRef | EArchiveReplaceObjectFlags::IgnoreArchetypeRef);
		if (ReplaceObjectArch.GetCount())
			bHasDependency = true;

		if (bHasDependency)
			DependencyBPs.Add(BP);
	}
		

	return DependencyBPs;
}

void UEditorUtils::HotReloadV2(FNimHotReload* NimHotReload) {
	TMap<UScriptStruct*, UScriptStruct*> ReloadStructs = NimHotReload->StructsToReinstance;
	TMap<UClass*, UClass*> ReloadClasses = NimHotReload->ClassesToReinstance;	

	TArray<UBlueprint*> DependencyBPs;
	TArray<UK2Node*> AllNodes;
	// Go through all blueprints and find any that are using a struct
	// or delegate that we have replaced, and change their pins
	// to point to the new ones instead.
	
	TMap<UObject*, UObject*> ClassReplaceList;
	for (auto& Elem : ReloadClasses)
		ClassReplaceList.Add(Elem.Key, Elem.Value);
	for (auto& Elem : ReloadStructs)
		ClassReplaceList.Add(Elem.Key, Elem.Value);

	auto ReplacePinType = [&](FEdGraphPinType& PinType) -> bool
	{
		if (PinType.PinCategory != UEdGraphSchema_K2::PC_Struct)
			return false;

		UScriptStruct* Struct = Cast<UScriptStruct>(PinType.PinSubCategoryObject.Get());
		if (Struct == nullptr)
			return false;

		UScriptStruct** NewStruct = ReloadStructs.Find(Struct);
		if (NewStruct == nullptr)
			return false;

		PinType.PinSubCategoryObject = *NewStruct;
		return true;
	};

	for (TObjectIterator<UBlueprint> BlueprintIt; BlueprintIt; ++BlueprintIt)
	{
		UBlueprint* BP = *BlueprintIt;

		AllNodes.Reset();
		FBlueprintEditorUtils::GetAllNodesOfClass(BP, AllNodes);

		bool bHasDependency = false;
		for (UK2Node* Node : AllNodes)
		{
			TArray<UStruct*> Dependencies;
			if (Node->HasExternalDependencies(&Dependencies))
			{
				for (UStruct* Struct : Dependencies)
				{
					if (ReloadClasses.Contains((UClass*)Struct))
						bHasDependency = true;
					if (ReloadStructs.Contains((UScriptStruct*)Struct))
						bHasDependency = true;

					if (bHasDependency)
						break;
				}
			}

			for (auto* Pin : Node->Pins)
			{
				bHasDependency |= ReplacePinType(Pin->PinType);
			}

			if (auto* EditableBase = Cast<UK2Node_EditablePinBase>(Node))
			{
				for (auto Desc : EditableBase->UserDefinedPins)
				{
					bHasDependency |= ReplacePinType(Desc->PinType);
				}
			}
			// TODO GetTiedSignatureFunction needs to be reimplemented or rething. They modified the engine to get it
			// if (auto* Event = Cast<UK2Node_Event>(Node))
			// {
			// 	if (auto* Function = Cast<UDelegateFunction>(Event->GetTiedSignatureFunction()))
			// 	{
			// 		if (NimHotReload->NewDelegateFunctions.Contains(Function) || NimHotReload->DelegatesToReinstance.Contains(Function))
			// 		{
			// 			bHasDependency = true;
			// 		}
			// 	}
			// // }

			if (auto* MacroInst = Cast<UK2Node_MacroInstance>(Node))
			{
				bHasDependency |= ReplacePinType(MacroInst->ResolvedWildcardType);
			}
		}

		for (auto& Variable : BP->NewVariables)
		{
			bHasDependency |= ReplacePinType(Variable.VarType);
		}

		// Check if the blueprint references any of our replacing classes at all
		FArchiveReplaceObjectRef<UObject> ReplaceObjectArch(
			BP, ClassReplaceList,
			EArchiveReplaceObjectFlags::IgnoreOuterRef | EArchiveReplaceObjectFlags::IgnoreArchetypeRef);
		if (ReplaceObjectArch.GetCount())
			bHasDependency = true;

		if (bHasDependency)
			DependencyBPs.Add(BP);
	}
		
		for (auto& Struct : ReloadStructs)
		{
			// FStructureEditorUtils::BroadcastPreChange(Cast<UUserDefinedStruct>(Struct.Key)); //TODO this are UserDefinedStrucs. We use Native structs. Maybe we should change them?
			
			
			// Update struct pointers in DataTable with newly generated replacements.
			// TArray<UDataTable*> Tables = GetTablesDependentOnStruct(Struct.Key);
			// for (UDataTable* Table : Tables)
			// {
			// 	Table->RowStruct = Struct.Value;
			// }
		}

	

		// Do a full-on garbage collection step to make sure old stuff is gone
		// before we start reinstancing things we no longer need.
		// CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);

		// Call into unreal's standard reinstancing system to
		// actually recreate objects using the old classes.
		// FBlueprintCompilationManager::ReparentHierarchies(ReloadClasses);

		// Do a full-on garbage collection step to make sure old stuff is gone
		// by the time we recompile blueprints below.
		// CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true); 

		// Make sure all blueprints that had dependencies to structs or delegates
		// are now properly recompiled.
		if (DependencyBPs.Num() != 0)
		{
			TSet<UClass*> NewlyCreatedClasses;
			for (auto& Elem : ReloadClasses)
				NewlyCreatedClasses.Add(Elem.Value);
			TSet<UScriptStruct*> NewlyCreatedStructs;
			for (auto& Elem : ReloadStructs)
				NewlyCreatedStructs.Add(Elem.Value);

			// Refresh nodes in blueprint graphs that depend on stuff we've reloaded.
			// If we don't do this then we will get errors until the nodes are manually refreshed!
			auto RefreshRelevantNodesInBP = [&](UBlueprint* BP)
			{
				AllNodes.Reset();
				FBlueprintEditorUtils::GetAllNodesOfClass(BP, AllNodes);

				auto CheckRefresh = [&](FEdGraphPinType& PinType) -> bool
				{
					if (PinType.PinCategory != UEdGraphSchema_K2::PC_Struct)
						return false;

					UScriptStruct* Struct = Cast<UScriptStruct>(PinType.PinSubCategoryObject.Get());
					return NewlyCreatedStructs.Contains(Struct);
				};

				for (UK2Node* Node : AllNodes)
				{
					TArray<UStruct*> Dependencies;
					bool bShouldRefresh = false;

					if (Node->HasExternalDependencies(&Dependencies))
					{
						for (UStruct* Struct : Dependencies)
						{
							if (NewlyCreatedClasses.Contains((UClass*)Struct))
							{
								bShouldRefresh = true;
								break;
							}
							if (NewlyCreatedStructs.Contains((UScriptStruct*)Struct))
							{
								bShouldRefresh = true;
								break;
							}
						}
					}

					if (NewlyCreatedStructs.Num() != 0 && !bShouldRefresh)
					{
						for (auto* Pin : Node->Pins)
						{
							bShouldRefresh |= CheckRefresh(Pin->PinType);
						}
					}

					if (auto* EditableBase = Cast<UK2Node_EditablePinBase>(Node))
					{
						for (auto Desc : EditableBase->UserDefinedPins)
						{
							bShouldRefresh |= CheckRefresh(Desc->PinType);
						}
					}

					// if (auto* Event = Cast<UK2Node_Event>(Node))
					// {
					// 	if (auto* Function = Cast<UDelegateFunction>(Event->GetTiedSignatureFunction()))
					// 	{
					// 		if (NewDelegates.Contains(Function) || ReloadDelegates.Contains(Function))
					// 		{
					// 			bShouldRefresh = true;
					// 		}
					// 	}
					// }

					if (auto* MacroInst = Cast<UK2Node_MacroInstance>(Node))
					{
						bShouldRefresh |= CheckRefresh(MacroInst->ResolvedWildcardType);
					}
					if (bShouldRefresh)
					{
						const UEdGraphSchema* Schema = Node->GetGraph()->GetSchema();
						Schema->ReconstructNode(*Node, true);
					}
				}
			};


			// Trigger a compile of all blueprints that we detected dependencies to our class in
			for (UBlueprint* BP : DependencyBPs)
			{
				RefreshRelevantNodesInBP(BP);
				FBlueprintCompilationManager::QueueForCompilation(BP);
			}

			// FBlueprintCompilationManager::FlushCompilationQueueAndReinstance();
		}

		for (auto& Struct : ReloadStructs)
		{
			//Try to remove the FProperties
			// for (TFieldIterator<FProperty> It(Struct.Key); It; ++It) {
			// 	// (*It)->Conditional();
			// }
			// Struct.Key->ConditionalBeginDestroy();
			// FStructureEditorUtils::BroadcastPostChange(Cast<UUserDefinedStruct>(Struct.Value)); //SAME AS ABOVE
			// FStructureEditorUtils::FStructEditorManager::Get().PostChange(Struct.Key);
			// FBlueprintEditorUtils::ChangeLocalVariableType(Bl);
		}
		

		//If the above doesnt work 
		// FBlueprintEditorUtils::variable

	
	// If we've created any new volumes, we want to make sure they have actor factories
	TArray<UClass*> NewVolumeClasses;
	for (UClass* NewClass : NimHotReload->NewClasses)
	{
		if (NewClass != nullptr && NewClass->IsChildOf(AVolume::StaticClass()))
			NewVolumeClasses.Add(NewClass);
	}
	

	if (NewVolumeClasses.Num() != 0)
	{
		TArray<UClass*> VolumeFactoryClasses;

		// Find all actor factories we use for volumes
		for (TObjectIterator<UClass> ObjectIt; ObjectIt; ++ObjectIt)
		{
			UClass* TestClass = *ObjectIt;
			if (TestClass->IsChildOf(UActorFactoryVolume::StaticClass()) && !TestClass->HasAnyClassFlags(CLASS_Abstract))
				VolumeFactoryClasses.Add(TestClass);
		}
		
		// Generate factories for the volume actor we just created
		for (UClass* VolumeFactoryClass : VolumeFactoryClasses)
		{
			for (UClass* VolumeClass : NewVolumeClasses)
			{
				UActorFactory* NewFactory = NewObject<UActorFactory>(GetTransientPackage(), VolumeFactoryClass);
				check(NewFactory);
				NewFactory->NewActorClass = VolumeClass;
				GEditor->ActorFactories.Add(NewFactory);
			}
		}
	}






//POST RELOAD
	PostReload();
}

void UEditorUtils::ShowLoadNotification(bool bIsFirstLoad) {
	AsyncTask(ENamedThreads::GameThread, [bIsFirstLoad] {
	
	FString NimUserMsg = (bIsFirstLoad ? "Nim Initialized!" : "Nim Hot Reload Complete!");
	// FNotificationInfo Info( FInternationalization::ForUseOnlyByLocMacroAndGraphNodeTextLiterals_CreateText(TEXT("NimForUE.HotReload"), *NimUserMsg, TEXT("NimForUE.HotReload")));
	FNotificationInfo Info( LOCTEXT("HotReloadFinished", "Nim Hot Reload Complete!") );
	Info.Image = FEditorStyle::GetBrush(TEXT("LevelEditor.RecompileGameCode"));
	Info.FadeInDuration = 0.1f;
	Info.FadeOutDuration = 0.5f;
	Info.ExpireDuration = 1.5f;
	Info.bUseThrobber = false;
	Info.bUseSuccessFailIcons = true;
	Info.bUseLargeFont = true;
	Info.bFireAndForget = false;
	Info.bAllowThrottleWhenFrameRateIsLow = false;

	auto NotificationItem = FSlateNotificationManager::Get().AddNotification( Info );
	NotificationItem->SetCompletionState(SNotificationItem::CS_Success);
	NotificationItem->ExpireAndFadeout();
			
	GEditor->PlayEditorSound(TEXT("/Engine/EditorSounds/Notifications/CompileSuccess_Cue.CompileSuccess_Cue"));
	});

}



#undef LOCTEXT_NAMESPACE
