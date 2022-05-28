// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
//#include "Misc/CoreDelegates.h"
#include "Tickable.h"
#include "Subsystems/EngineSubsystem.h"
#include "NimForUEEngineSubsystem.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(NimForUEEngineSubsystem, Log, All);

/**
 * 
 */
UCLASS()
class NIMFORUE_API UNimForUEEngineSubsystem : public UEngineSubsystem, public FTickableGameObject
{
	GENERATED_BODY()
public:
	// USubsystem methods //
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// FTickableObjectBase methods //
	virtual ETickableTickType GetTickableTickType() const override { return ETickableTickType::Always; }
	virtual TStatId GetStatId() const override;
	virtual void Tick(float DeltaTime) override;
	virtual bool IsAllowedToTick() const { return !IsTemplate(); } // This is to prevent the CDO from ticking.

	// FTickableGameObject methods //
	virtual bool IsTickableWhenPaused() const override { return true; }
	virtual bool IsTickableInEditor() const override { return true; }

private:
	float elapsedSeconds;
};
