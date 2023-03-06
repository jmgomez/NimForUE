// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/EngineSubsystem.h"
#include "Containers/Ticker.h"
#include "NimForUEEngineSubsystem.generated.h"


/**
 * 
 */
// UCLASS(Abstract)
//THe proper solution will be to move this to the EditorModule
UCLASS()
class NIMFORUE_API UNimForUEEngineSubsystem : public UEngineSubsystem {
	GENERATED_BODY()
	void* NimForUEHandle = nullptr;
	void LoadNimForUEHost();
	UNimForUEEngineSubsystem();
	bool Tick(float DeltaTime);
	FTSTicker::FDelegateHandle TickDelegateHandle;
	static void LoadNimGuest(FString NimError);
public:
	// UPROPERTY()
	// class UEditorUtils* EditorUtils;
	const FString NimPluginModule = "Nim";
	//Holds the number of reload per module. i.e. NimPlugin -> 1, NimGame -> 2
	TMap<FString, int> ReloadCounter = {};
	// USubsystem methods //
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;
	int GetReloadTimesFor(FString ModuleName);
};
