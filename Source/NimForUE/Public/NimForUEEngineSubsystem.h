// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/EngineSubsystem.h"
#include "Containers/Ticker.h"
#include "NimForUEEngineSubsystem.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(NimForUEEngineSubsystem, Log, All);

/**
 * 
 */
UCLASS()
class NIMFORUE_API UNimForUEEngineSubsystem : public UEngineSubsystem {
	GENERATED_BODY()
	UPROPERTY()
	//Package where all nim classes will live.
	UPackage* NimForUEPackage;
	UPROPERTY()
	class UEditorUtils* EditorUtils;
	bool Tick(float DeltaTime);
	FTSTicker::FDelegateHandle TickDelegateHandle;
	static void LoadNimGuest(FString Msg);
	void CreateNimPackage();
public:
	int ReloadTimes;
	// USubsystem methods //
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

};
