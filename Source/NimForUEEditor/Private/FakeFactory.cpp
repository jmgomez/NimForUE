// Fill out your copyright notice in the Description page of Project Settings.


#include "FakeFactory.h"
#include "NimForUEEditor/NimForUEEditor.h"
#include "Editor.h"


void UFakeFactory::BroadcastAsset(UObject* AssetToBroadcast) {
	UE_LOG(NimForUEEditor, Warning, TEXT("Nim Broadcast asset called!"))
	GEditor->GetEditorSubsystem<UImportSubsystem>()->BroadcastAssetPostImport(nullptr, AssetToBroadcast);
}
