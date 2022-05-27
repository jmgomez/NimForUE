// Fill out your copyright notice in the Description page of Project Settings.

#include "NimForUEWatcher.h"

#include "NimForUEFFI.h"

DEFINE_LOG_CATEGORY(Watcher);

// Sets default values
ANimForUEWatcher::ANimForUEWatcher()
{
 	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;
}

// Called when the game starts or when spawned
void ANimForUEWatcher::BeginPlay()
{
	Super::BeginPlay();
	checkReload();
	elapsedSeconds = 0.0;
}

// Called every frame
void ANimForUEWatcher::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	elapsedSeconds += DeltaTime;
	if (elapsedSeconds > 1.0)
	{
		checkReload();
		elapsedSeconds = 0.0;
	}
}

