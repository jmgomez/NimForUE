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
class NIMFORUE_API UNimForUEEngineSubsystem : public UEngineSubsystem
{
	GENERATED_BODY()
public:
	// USubsystem methods //
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

private:

	bool Tick(float DeltaTime);
	FTSTicker::FDelegateHandle TickDelegateHandle;
	float elapsedSeconds;
};
