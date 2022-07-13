// Fill out your copyright notice in the Description page of Project Settings.


#include "EditorUtils.h"

#include "BlueprintCompilationManager.h"
#include "BlueprintEditor.h"
#include "FileHelpers.h"
#include "FNimReload.h"
#include "K2Node_MacroInstance.h"
#include "AssetRegistry/AssetRegistryModule.h"
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


void UEditorUtils::RefreshNodes(TUniquePtr<FNimHotReload> NimHotReload) {
	// This function is called when the main "Refresh All Blueprint Nodes" button in pressed
	// FBlueprintCompilationManager::ReparentHierarchies(NimHotReload->ClassesToReinstance);
	FARFilter Filter;
	Filter.ClassNames.Add(UBlueprint::StaticClass()->GetFName());
	Filter.bRecursiveClasses = true;
	Filter.bRecursivePaths = true;


	
	
	Filter.ClassNames.Add(UWorld::StaticClass()->GetFName());

	Filter.PackagePaths.Add("/Game");
	

	

	TArray<FAssetData> AssetData;
	TArray<UPackage*> PackagesToSave;

	// ProblemBlueprints is filled with blueprints when there are errors, but only emptied here...
	// It really should be emptied after the ProblemNotification fades out.
	TArray<UBlueprint*> ProblemBlueprints = {};
	
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");

	// Search for applicable assets (UBlueprints, possibly UWorlds)
	AssetRegistryModule.Get().GetAssets(Filter, AssetData);
	int NumAssets = AssetData.Num();

	TSharedPtr<SNotificationItem> RefreshingNotification;

	// Create different popups depending on whether there are blueprints to refresh or not
	if (NumAssets) {
		FNotificationInfo Info(FText::Format(FText::FromString("Refreshing {0}..."), (NumAssets)));
		Info.ExpireDuration = 5;
		Info.bFireAndForget = false;
		RefreshingNotification = FSlateNotificationManager::Get().AddNotification(Info);
		RefreshingNotification->SetCompletionState(SNotificationItem::CS_Pending);
	} else {
		FNotificationInfo Info(FText::FromString("No blueprints were refreshed"));
		Info.ExpireDuration = 1.5f;
	
		FSlateNotificationManager::Get().AddNotification(Info);
	}

	// Loop through the assets, get to the blueprints, and refresh them
	for (FAssetData Data : AssetData) {

		FString AssetPathString = Data.ObjectPath.ToString();
		
		TWeakObjectPtr<UBlueprint> Blueprint = Cast<UBlueprint>(Data.GetAsset());
		
		// Try casting to a UWorld (to get level blueprint)
		if (Blueprint == nullptr)  {
			TWeakObjectPtr<UWorld> World = Cast<UWorld>(Data.GetAsset());
			if (World != nullptr) {
				TWeakObjectPtr<ULevel> Level = World->GetCurrentLevel();

				if (Level != nullptr) {
					// Use the level blueprint
					Blueprint = reinterpret_cast<UBlueprint*>(Level->GetLevelScriptBlueprint(true));
				}
			}
		}
	      
		// Skip if there is no blueprint
		if (Blueprint == nullptr)  {
			continue;
		}

		UE_LOG(NimForUEEditor, Display, TEXT("Refreshing Blueprint: %s"), *AssetPathString);
		
		//
		// for (const auto& ClassToReinstancePair : NimHotReload->ClassesToReinstance) {
		// 	if(!ClassToReinstancePair.Key) continue;
		// 	// Refresh all nodes in this blueprint
		// 	// UClass* NativeParentclass = FBlueprintEditorUtils::GetNativeParent(Blueprint.Get());
		// 	UE_LOG(NimForUEEditor, Log, TEXT("Checking if Blueprint: %s with is child of %s" ), *AssetPathString, *ClassToReinstancePair.Key->GetName());
		// 	if(AssetPathString.Contains("_Base")) {
		// 		
		// 	}
		// 	if(Blueprint->ParentClass->IsChildOf(ClassToReinstancePair.Key->GetClass())) {
		// 		UE_LOG(NimForUEEditor, Warning, TEXT("The Blueprint: %s is child of %s" ), *AssetPathString, *ClassToReinstancePair.Key->GetName());
		//
		// 	}
		// }

		//if(AssetPathString.Contains("_Base")) {
		//	FBlueprintEditorUtils::
		//}else {
			FBlueprintEditorUtils::RefreshAllNodes(Blueprint.Get());
		//}

		CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);


		// // Compile blueprint
		// UE_LOG(NimForUEEditor, Display, TEXT("Compiling Blueprint: %s"), *AssetPathString);
		// // FKismetEditorUtilities::CompileBlueprint(Blueprint.Get(), EBlueprintCompileOptions::BatchCompile | EBlueprintCompileOptions::SkipSave);
		//
		// // Check if the blueprint failed to compile
		// if (!Blueprint->IsUpToDate() && Blueprint->Status != BS_Unknown) {
		// 	UE_LOG(NimForUEEditor, Error, TEXT("Failed to compile %s"), *AssetPathString);
		// 	ProblemBlueprints.Add(Blueprint.Get());
		// }
		//

		PackagesToSave.Add(Data.GetPackage());
	}

	// Save the refreshed blueprints
	// bool bSuccess = UEditorLoadingAndSavingUtils::SavePackages(PackagesToSave, true);
	bool bSuccess = true;// = UEditorLoadingAndSavingUtils::SavePackages(PackagesToSave, true);

	// If the saving fails, log and error and raise a notification
	if (!bSuccess) {
		UE_LOG(NimForUEEditor, Error, TEXT("Failed to save packages"));
		FNotificationInfo Info(FText::FromString("Failed to save packages"));
		Info.ExpireDuration = 10.f;
	
		FSlateNotificationManager::Get().AddNotification(Info)->SetCompletionState(SNotificationItem::CS_Fail);
	}

	// Set the popup to "success" state
	if (RefreshingNotification.IsValid()) {
		RefreshingNotification->SetText(FText::Format(FText::FromString("Refreshed {0}"), (NumAssets)));
		RefreshingNotification->SetCompletionState(SNotificationItem::CS_Success);
		RefreshingNotification->ExpireAndFadeout();
	}
	//
	// // If there were errors in compilation, create a new popup with an option to see which blueprints failed to compile
	// if (ProblemBlueprints.Num()) {
	// 	auto ShowBlueprints = [this]
	//       	{	
	// 		if (ProblemBlueprints.Num()) {
	// 			ShowProblemBlueprintsDialog(ProblemBlueprints);
	// 		}
	// 	};
	//
	// 	FNotificationInfo Info(FText::Format(FText::FromString("{0} failed to compile"), BLUEPRINTS_TEXT(ProblemBlueprints.Num())));
	// 	Info.ExpireDuration = 15;
	// 	Info.Image = FEditorStyle::GetBrush("Icons.Warning");
	//
	// 	TSharedPtr<SNotificationItem> ProblemNotification;
	//        	ProblemNotification = FSlateNotificationManager::Get().AddNotification(Info);
	// 	ProblemNotification->SetHyperlink(FSimpleDelegate::CreateLambda(ShowBlueprints), FText::FromString("Show blueprints"));
	//}
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

	delete NimHotReload;
}

void UEditorUtils::HotReload(FNimHotReload* NimHotReload) {
	if (NimHotReload->bShouldHotReload){
		FNimReload* Reload(new FNimReload(EActiveReloadType::HotReload, TEXT(""), *GLog));

		for (const auto& ClassToReinstancePair : NimHotReload->ClassesToReinstance)
			Reload->NotifyChange(ClassToReinstancePair.Value, ClassToReinstancePair.Key);
		
		for (const auto& StructToReinstancePair : NimHotReload->StructsToReinstance)
			Reload->NotifyChange(StructToReinstancePair.Value, StructToReinstancePair.Key);
		
		
		Reload->Reinstance();
		Reload->Finalize(true);
		Reload->SetSendReloadCompleteNotification(true);

		delete Reload;
	}
	delete NimHotReload;
}
