#include "ReinstanceBindings.h"

#include "NimForUEEngineSubsystem.h"
#include "Engine/Engine.h"
#if WITH_EDITOR
#include "EditorUtils.h"
#include "Kismet2/ReloadUtilities.h"



void ReinstanceBindings::ReinstanceNueTypes(FString NueModule, FNimHotReload* NimHotReload, FString NimError, bool bReuseHotReload) {
	UNimForUEEngineSubsystem* NimForUESubsystem = GEngine->GetEngineSubsystem<UNimForUEEngineSubsystem>();
	// bool bIsFirstLoad = !NimForUESubsystem->ReloadCounter.Contains(NueModule);
	bool bIsFirstLoad = false;// !NimForUESubsystem->ReloadCounter.Contains(NueModule);
	
	IReload* UnrealReload = GetActiveReloadInterface(); //TODO send over where it come from because maybe it's already enable (or can it be tested)?
	//we try to use the unreal reloader in case we are in the middle of one reloading
	if(UnrealReload == nullptr and not bReuseHotReload) //We need to instanciate the unreal reloader because it's used across the engine when reloading
		UnrealReload = new FReload(EActiveReloadType::HotReload, TEXT(""), *GLog);

	if(bIsFirstLoad) {//Only crash on first load
		checkf(NimHotReload, TEXT("NimHotReload is null. Probably nim crashed on startup. See the log for a stacktrace."));
	}
	if(NimHotReload == nullptr){
		UE_LOG(LogTemp, Error, TEXT("NimForUE just crashed. Review the log"), *NimError);
		// delete UnrealReload;
		return;
		
	}
	UE_LOG(LogTemp, Log, TEXT("NimForUE NIMHOTRELOAD! %i"), NimHotReload->GetNumber());

	if (NimHotReload->bShouldHotReload && !bIsFirstLoad) {
		// if (!bIsFirstLoad) {
	 NewObject<UEditorUtils>()->HotReload(NimHotReload, UnrealReload, bReuseHotReload);
	
	}
	// if (UnrealReload != nullptr) //Unreal will clean it up. TODO flags if we are the one that started it
	// 	delete UnrealReload;
	// delete NimHotReload;

	// FCoreUObjectDelegates::ReloadCompleteDelegate.Broadcast(EReloadCompleteReason::HotReloadManual);
	UEditorUtils::ShowLoadNotification(bIsFirstLoad);

		
}

#endif

