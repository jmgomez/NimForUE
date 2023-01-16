// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"
#include "Modules/ModuleManager.h"
#if WITH_EDITOR
	#include "Editor.h"
	#include "EditorUtils.h"
#include "NimForUEFFI.h"

#else
#include "NimForUEGame.h"
#endif
#include "Async/Async.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Widgets/Notifications/SNotificationList.h"
#include "Test/NimTestBase.h"

DEFINE_LOG_CATEGORY(NimForUE);

#include "Interfaces/IPluginManager.h"

#define LOCTEXT_NAMESPACE "FNimForUEModule"




void FNimForUEModule::LoadNimForUEHost() {
	//Notice MacOS does not require to manually load the library. It happens on the build.cs file.
	//The gues library, it's loaded in the EngineSubsystem
	UE_LOG(NimForUE, Log, TEXT("Will load NimForUEHost now..."));

#if PLATFORM_WINDOWS
	FString PluginPath =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	
	FString DllPath = FPaths::Combine(PluginPath, "\\Binaries\\nim\\ue\\hostnimforue.dll");
	//Ideally it will be set through a Deinition to keep one source of truth
	//FString DllPath = NIM_FOR_UE_LIB_PATH;
	NimForUEHandle = FPlatformProcess::GetDllHandle(*DllPath);
	FString Cmd = FString::Printf(TEXT("nue.exe"));
	int ReturnCode;
	FString StdOutput;
	FString StdError;
	//FPlatformProcess::ExecProcess(*Cmd, TEXT("gencppbindings"), &ReturnCode, &StdOutput, &StdError, *PluginPath);
	// UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib loaded %s"), *DllPath);
	// UE_LOG(NimForUE, Warning, TEXT("NimForUE Out %s"), *StdOutput);
	// UE_LOG(NimForUE, Error, TEXT("NimForUE Error %s"), *StdError);
#endif
}

void FNimForUEModule::UnloadNimForUEHost() {
#if PLATFORM_WINDOWS
	FPlatformProcess::FreeDllHandle(NimForUEHandle);
	NimForUEHandle = nullptr;
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib unloaded %d"));
#endif
}

#if WITH_STARTNUE
extern "C" N_LIB_PRIVATE N_CDECL(void, startNue)(void);
#endif

#if !WITH_EDITOR
N_CDECL(void, NimMain)(void);

#endif

void FNimForUEModule::StartupModule()
{
#if WITH_STARTNUE
	// If we are cooking we just skip
	 if (IsRunningCommandlet()) {
	 	NimMain();
	 	startNue();
	 	return;
	 }
#endif
#if WITH_EDITOR
	LoadNimForUEHost();
#elif WITH_STARTNUE
	NimMain();
	startNue();
#endif
	
}

void FNimForUEModule::ShutdownModule()
{
	//If we are cooking we just skip
	if (IsRunningCommandlet()) return;
	UnloadNimForUEHost();
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)