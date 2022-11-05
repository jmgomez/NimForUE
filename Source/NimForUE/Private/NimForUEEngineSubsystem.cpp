// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"

#include "Editor.h"
#include "EditorUtils.h"
#include "FNimReload.h"
#include "NimForUEFFI.h"
#include "ReinstanceBindings.h"


void UNimForUEEngineSubsystem::LoadNimGuest(FString NimError) {
	//Notice this function is static because it needs to be used in a FFI function.
	UNimForUEEngineSubsystem* THIS = GEngine->GetEngineSubsystem<UNimForUEEngineSubsystem>();
	// onNimForUELoaded(THIS->GetReloadTimesFor(THIS->NimPluginModule));
	// 	//The return value is not longer needed since the reinstance call now happens on nim
	// return;
	// // FNimHotReload* NimHotReload = static_cast<FNimHotReload*>(onNimForUELoaded(THIS->GetReloadTimesFor(THIS->NimPluginModule)));
	// ReinstanceBindings::ReinstanceNueTypes(THIS->NimPluginModule, NimHotReload, NimError);
}





void UNimForUEEngineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	initializeHost();

	auto onPostReload = [](NCSTRING msg) {
		LoadNimGuest(FString(msg));
	};
	auto logger = [](NCSTRING msg) {
		UE_LOG(LogTemp, Log, TEXT("From NimForUEHost: %s"), *FString(msg));
	};
	registerLogger(logger);
	// subscribeToReload(onPreReload, onPostReload);
	
	checkReload();

	TickDelegateHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UNimForUEEngineSubsystem::Tick), 0.1);
}

void UNimForUEEngineSubsystem::Deinitialize()
{
	FTSTicker::GetCoreTicker().RemoveTicker(TickDelegateHandle);
}

int UNimForUEEngineSubsystem::GetReloadTimesFor(FString ModuleName) {
	if(ReloadCounter.Contains(ModuleName)) {
		return ReloadCounter[ModuleName];
	}
	return 0;
}

bool UNimForUEEngineSubsystem::Tick(float DeltaTime)
{
	if (EditorUtils)
		EditorUtils->Tick(DeltaTime);
	checkReload();
	return true;
}
