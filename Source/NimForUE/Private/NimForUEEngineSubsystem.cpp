// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"

#include "NimForUEFFI.h"

DEFINE_LOG_CATEGORY(NimForUEEngineSubsystem);

void UNimForUEEngineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	initializeHost();
	checkReload();
	elapsedSeconds = 0.0;
}

void UNimForUEEngineSubsystem::Deinitialize()
{
}

// FTickableObjectBase methods //
TStatId UNimForUEEngineSubsystem::GetStatId() const
{
	RETURN_QUICK_DECLARE_CYCLE_STAT(NimForUEEngineSubsystem, STATGROUP_Tickables);
}

void UNimForUEEngineSubsystem::Tick(float DeltaTime)
{
	elapsedSeconds += DeltaTime;
	if (elapsedSeconds > 0.1)
	{
		checkReload();
		elapsedSeconds = 0.0;
	}
}
