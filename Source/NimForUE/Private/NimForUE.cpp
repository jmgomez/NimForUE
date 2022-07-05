// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"
#include "Modules/ModuleManager.h"
#include "Editor.h"
#include "NimForUEFFI.h"
#include "Async/Async.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Widgets/Notifications/SNotificationList.h"
#include "Test/NimTestBase.h"

DEFINE_LOG_CATEGORY(NimForUE);

#include "Interfaces/IPluginManager.h"

#define LOCTEXT_NAMESPACE "FNimForUEModule"


void FNimForUEModule::StartupModule()
{
#if PLATFORM_WINDOWS
	FString PluginPath =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	
	
	FString DllPath = FPaths::Combine(PluginPath, "\\Binaries\\nim\\ue\\hostnimforue.dll");
	//Ideally it will be set through a Deinition to keep one source of truth
	//FString DllPath = NIM_FOR_UE_LIB_PATH;
	
	NimForUEHandle = FPlatformProcess::GetDllHandle(*DllPath);
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib loaded %s"), *DllPath);

#endif
	
	auto onPreReload = [](NCSTRING msg) {
		// subscribeToReloadWorkaround until we have a proper HotReload Load/Unload mechanism
		// FNimTestBase::UnregisterAll();
	};
	auto onPostReload = [](NCSTRING msg) {

		//TODO Do it only for development target and maybe based on config (retrieved from nim)

		AsyncTask(ENamedThreads::GameThread, [] {
			
			FNotificationInfo Info( LOCTEXT("HotReloadFinished", "Nim Hot Reload Complete!") );
			Info.Image = FEditorStyle::GetBrush(TEXT("LevelEditor.RecompileGameCode"));
			Info.FadeInDuration = 0.1f;
			Info.FadeOutDuration = 0.5f;
			Info.ExpireDuration = 1.5f;
			Info.bUseThrobber = false;
			Info.bUseSuccessFailIcons = true;
			Info.bUseLargeFont = true;
			Info.bFireAndForget = false;
			Info.bAllowThrottleWhenFrameRateIsLow = false;
			// //Fails because it's on another thread?
			auto NotificationItem = FSlateNotificationManager::Get().AddNotification( Info );
			NotificationItem->SetCompletionState(SNotificationItem::CS_Success);
			NotificationItem->ExpireAndFadeout();
			
			GEditor->PlayEditorSound(TEXT("/Engine/EditorSounds/Notifications/CompileSuccess_Cue.CompileSuccess_Cue"));
			
		});
		onNimForUELoaded(ReloadTimes++);
		UE_LOG(NimForUE, Log, TEXT("NimForUE just hot reloaded! %s"), ANSI_TO_TCHAR(msg));
		FCoreUObjectDelegates::ReloadCompleteDelegate.Broadcast(EReloadCompleteReason::HotReloadManual);

	};

	
	//TODO Do it only for development target and maybe based on config (retrieved from nim)
	subscribeToReload(onPreReload, onPostReload);
		
		
}

void FNimForUEModule::ShutdownModule()
{
#if PLATFORM_WINDOWS
	FPlatformProcess::FreeDllHandle(NimForUEHandle);
	NimForUEHandle = nullptr;
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib unloaded %d"));
#endif
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)