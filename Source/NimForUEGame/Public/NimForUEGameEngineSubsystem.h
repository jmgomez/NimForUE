// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "NimForUEGameEngineSubsystem.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEGAME_API UNimForUEGameEngineSubsystem : public UEngineSubsystem {
	GENERATED_BODY()
	void Initialize(FSubsystemCollectionBase& Collection) override;
};
