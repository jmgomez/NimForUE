// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"

#include "Editor.h"
#include "NimForUEFFI.h"
#include "Async/Async.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Widgets/Notifications/SNotificationList.h"
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
	//TODO Do it only for development target and maybe based on config (retrieved from nim)
	subscribeToReload([](NCSTRING msg) {
		

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
			// //Fails because it's on antother thread?
			auto NotificationItem = FSlateNotificationManager::Get().AddNotification( Info );
			NotificationItem->SetCompletionState(SNotificationItem::CS_Success);
			NotificationItem->ExpireAndFadeout();
			
			GEditor->PlayEditorSound(TEXT("/Engine/EditorSounds/Notifications/CompileSuccess_Cue.CompileSuccess_Cue"));
			
		});

		initNimForUE();
		UE_LOG(NimForUE, Log, TEXT("NimForUE just hot reloaded! %s"), ANSI_TO_TCHAR(msg));
	});
	startWatch();
	
}

void FNimForUEModule::ShutdownModule()
{
#if PLATFORM_WINDOWS
	FPlatformProcess::FreeDllHandle(NimForUEHandle);
	NimForUEHandle = nullptr;
	UE_LOG(NimForUE, Log, TEXT("NimForUE FFI lib unloaded %d"));
#endif
	//TODO Implement
	stopWatch();
}

//"OLD" way of reloading where it starts in UE. Remove it when we know there arent major caveats with the way we are reloading now
void FNimForUEModule::PerformHotReload() {
	
#if WITH_EDITOR
	// FPlatformProcess::CreatePro
	// perfomHotReloadFFI();
	FString LibraryPath;
#if PLATFORM_WINDOWS
	
	// LibraryPath = GetLastFile(LibraryDirPath, CandidateLib);
#elif PLATFORM_MAC
	//TODO Replace this from getting the path via the FFI
	//TODO Define log category
	LibraryPath = "/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/Plugins/NimForUE/Binaries/nim/ue/libNimForUE-1.dylib";
#endif
	FString PathToProcess =  IPluginManager::Get().FindPlugin("NimForUE")->GetBaseDir();
	FProcHandle ProcHandle = FPlatformProcess::CreateProc(TEXT("nimble"), TEXT("buildnimforue"), false, false, false, 0, 0, *PathToProcess, nullptr, nullptr);
	FPlatformProcess::WaitForProc(ProcHandle); //TODO This whole thing can be made in another proc so the user doesnt have to wait
	char* NewLibChar = TCHAR_TO_ANSI(*LibraryPath);
	reloadlib(NewLibChar);
	UE_LOG(NimForUE, Warning, TEXT("Using %s as new lib"), *LibraryPath);
#endif
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)