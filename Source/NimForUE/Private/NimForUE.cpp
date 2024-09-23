// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"

#include <NimForUEFFI.h>

#include "Interfaces/IPluginManager.h"
#include "Modules/ModuleManager.h"
#if WITH_EDITOR
	#include "Editor.h"
#else
#endif

DEFINE_LOG_CATEGORY(NimForUE);

#define LOCTEXT_NAMESPACE "FNimFoUEModule"

void Logger(NCSTRING msg) {
	UE_LOG(LogTemp, Log, TEXT("From NimForUEHost: %s"), *FString(msg));
};

void FNimForUEModule::StartupModule()
{
   if (IsRunningCookCommandlet()) return;

#if WITH_EDITORONLY_DATA
	//Notice MacOS does not require to manually load the library. It happens on the build.cs file.
	//The gues library, it's loaded in the EngineSubsystem
	UE_LOG(NimForUE, Log, TEXT("Will load NimForUEHost now..."));

#if PLATFORM_WINDOWS
	FString PluginPath =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	
	FString DllPath = FPaths::Combine(PluginPath, "\\Binaries\\nim\\ue\\hostnimforue.dll");
	FPlatformProcess::GetDllHandle(*DllPath);
#endif

	registerLogger(Logger);
	ensureGuestIsCompiled();
	checkReload(0);
	#endif
}

void FNimForUEModule::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)