// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"
#include "Modules/ModuleManager.h"
#include "Editor.h"
#include "EditorUtils.h"
#include "NimForUEFFI.h"
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
#if PLATFORM_WINDOWS
	FString PluginPath =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	FString DllPath = FPaths::Combine(PluginPath, "\\Binaries\\nim\\ue\\hostnimforue.dll");
	//Ideally it will be set through a Deinition to keep one source of truth
	//FString DllPath = NIM_FOR_UE_LIB_PATH;
	NimForUEHandle = FPlatformProcess::GetDllHandle(*DllPath);
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib loaded %s"), *DllPath);
#endif
}

void FNimForUEModule::UnloadNimForUEHost() {
#if PLATFORM_WINDOWS
	FPlatformProcess::FreeDllHandle(NimForUEHandle);
	NimForUEHandle = nullptr;
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib unloaded %d"));
#endif
}

void FNimForUEModule::StartupModule()
{
	LoadNimForUEHost();
}

void FNimForUEModule::ShutdownModule()
{
	UnloadNimForUEHost();
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)