// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "TimerManager.h"
#include "NimForUEWatcher.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(Watcher, Log, All);

// Create a Blueprint with ANimForUEWatcher and drop an instance into your level.
UCLASS()
class NIMFORUE_API ANimForUEWatcher : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	ANimForUEWatcher();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	float elapsedSeconds;
};
