// Fill out your copyright notice in the Description page of Project Settings.


#include "EditorUtils.h"

#include "FileHelpers.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Kismet/KismetStringLibrary.h"
#include "Kismet2/BlueprintEditorUtils.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "NimForUEEditor/NimForUEEditor.h"
#include "Widgets/Notifications/SNotificationList.h"


void UEditorUtils::RefreshNodes() {
	// This function is called when the main "Refresh All Blueprint Nodes" button in pressed

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
	    
		// Refresh all nodes in this blueprint
		FBlueprintEditorUtils::RefreshAllNodes(Blueprint.Get());

	

		// Compile blueprint
		UE_LOG(NimForUEEditor, Display, TEXT("Compiling Blueprint: %s"), *AssetPathString);
		FKismetEditorUtilities::CompileBlueprint(Blueprint.Get(), EBlueprintCompileOptions::BatchCompile | EBlueprintCompileOptions::SkipSave);

		// Check if the blueprint failed to compile
		if (!Blueprint->IsUpToDate() && Blueprint->Status != BS_Unknown) {
			UE_LOG(NimForUEEditor, Error, TEXT("Failed to compile %s"), *AssetPathString);
			ProblemBlueprints.Add(Blueprint.Get());
		}
	

		PackagesToSave.Add(Data.GetPackage());
	}

	// Save the refreshed blueprints
	bool bSuccess = UEditorLoadingAndSavingUtils::SavePackages(PackagesToSave, true);

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
