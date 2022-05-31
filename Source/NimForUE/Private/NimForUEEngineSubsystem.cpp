// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"

#include "NimForUEFFI.h"

DEFINE_LOG_CATEGORY(NimForUEEngineSubsystem);

void UNimForUEEngineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	initializeHost();
	checkReload();
	elapsedSeconds = 0.0;
	TickDelegateHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UNimForUEEngineSubsystem::Tick));
}

void UNimForUEEngineSubsystem::Deinitialize()
{
	FTSTicker::GetCoreTicker().RemoveTicker(TickDelegateHandle);
}

bool UNimForUEEngineSubsystem::Tick(float DeltaTime)
{
	elapsedSeconds += DeltaTime;
	if (elapsedSeconds > 0.1)
	{
		checkReload();
		elapsedSeconds = 0.0;
	}
	return true;
}
