// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"
#if WITH_EDITOR
#include "Editor.h"
#include "EditorUtils.h"
#include "FNimReload.h"
#endif

#include "NimForUEFFI.h"
#include "ReinstanceBindings.h"
#include "Interfaces/IPluginManager.h"




void UNimForUEEngineSubsystem::LoadNimGuest(FString NimError) {
	//Notice this function is static because it needs to be used in a FFI function.
	UNimForUEEngineSubsystem* THIS = GEngine->GetEngineSubsystem<UNimForUEEngineSubsystem>();
	// onNimForUELoaded(THIS->GetReloadTimesFor(THIS->NimPluginModule));
	// 	//The return value is not longer needed since the reinstance call now happens on nim
	// return;
	// // FNimHotReload* NimHotReload = static_cast<FNimHotReload*>(onNimForUELoaded(THIS->GetReloadTimesFor(THIS->NimPluginModule)));
	// ReinstanceBindings::ReinstanceNueTypes(THIS->NimPluginModule, NimHotReload, NimError);
}


void Logger(NCSTRING msg) {
	UE_LOG(LogTemp, Log, TEXT("From NimForUEHost: %s"), *FString(msg));
};


void UNimForUEEngineSubsystem::LoadNimForUEHost() {
#if WITH_EDITORONLY_DATA
	//Notice MacOS does not require to manually load the library. It happens on the build.cs file.
	//The gues library, it's loaded in the EngineSubsystem
	UE_LOG(NimForUE, Log, TEXT("Will load NimForUEHost now..."));

#if PLATFORM_WINDOWS
	FString PluginPath =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	
	FString DllPath = FPaths::Combine(PluginPath, "\\Binaries\\nim\\ue\\hostnimforue.dll");
	//Ideally it will be set through a Deinition to keep one source of truth
	//FString DllPath = NIM_FOR_UE_LIB_PATH;
	NimForUEHandle = FPlatformProcess::GetDllHandle(*DllPath);
	#endif

	registerLogger(Logger);
	ensureGuestIsCompiled();
	checkReload(0);//before the engine is loaded. 
	#endif
}

UNimForUEEngineSubsystem::UNimForUEEngineSubsystem() {
	LoadNimForUEHost();
}

void UNimForUEEngineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	
#if WITH_EDITOR
	//Some modules use PostEngineInit but command lets only runs if PostDefault is set.
	//So we delay init
	FCoreDelegates::OnAllModuleLoadingPhasesComplete.AddLambda([this] {
		checkReload(1); //The first emission of types will occur at this point, after everything is loaded
	});
	
	
#endif
	TickDelegateHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UNimForUEEngineSubsystem::Tick), 0.1);

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
	checkReload(2);
#endif
	return true;
}

