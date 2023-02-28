// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"
#if WITH_EDITOR
#include "Editor.h"
#include "EditorUtils.h"
#include "FNimReload.h"
#endif

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

	
#if WITH_EDITOR
	//Some modules use PostEngineInit but command lets only runs if PostDefault is set.
	//So we delay init
	FCoreDelegates::OnAllModuleLoadingPhasesComplete.AddLambda([this] {
		auto logger = [](NCSTRING msg) {
		UE_LOG(LogTemp, Log, TEXT("From NimForUEHost: %s"), *FString(msg));
	};
		registerLogger(logger);
		ensureGuestIsCompiled();
		checkReload();
		TickDelegateHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UNimForUEEngineSubsystem::Tick), 0.1);
	});
	
	
#endif
}

void UNimForUEEngineSubsystem::Deinitialize()
{
#if WITH_EDITOR
	//If we are cooking we just skip
	if (IsRunningCommandlet()) return;
	FTSTicker::GetCoreTicker().RemoveTicker(TickDelegateHandle);
#endif
}

int UNimForUEEngineSubsystem::GetReloadTimesFor(FString ModuleName) {
	if(ReloadCounter.Contains(ModuleName)) {
		return ReloadCounter[ModuleName];
	}
	return 0;
}

bool UNimForUEEngineSubsystem::Tick(float DeltaTime)
{
#if WITH_EDITOR
	//If we are cooking we just skip
	if (IsRunningCommandlet()) return true;
	checkReload();
#endif
	return true;
}

