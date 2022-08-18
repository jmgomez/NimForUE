// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUEEngineSubsystem.h"

#include "Editor.h"
#include "EditorUtils.h"
#include "FNimReload.h"
#include "NimForUEFFI.h"

DEFINE_LOG_CATEGORY(NimForUEEngineSubsystem);

void UNimForUEEngineSubsystem::LoadNimGuest(FString Msg) {
	//Notice this function is static because it needs to be used in a FFI function.
	UNimForUEEngineSubsystem* NimForUESubsystem = GEngine->GetEngineSubsystem<UNimForUEEngineSubsystem>();
	bool bIsFirstLoad = NimForUESubsystem->ReloadTimes == 0;
	FReload* UnrealReload = nullptr;
	if(!bIsFirstLoad) //We need to instanciate the unreal reloader because it's used across the engine when reloading
		UnrealReload = new FReload(EActiveReloadType::HotReload, TEXT(""), *GLog);

	FNimHotReload* NimHotReload = static_cast<FNimHotReload*>(onNimForUELoaded(NimForUESubsystem->ReloadTimes));
	if(bIsFirstLoad) {//Only crash on first load
		checkf(NimHotReload, TEXT("NimHotReload is null. Probably nim crashed on startup. See the log for a stacktrace."));
	}
	if(NimHotReload == nullptr){
		UE_LOG(LogTemp, Error, TEXT("NimForUE just crashed. Review the log"), *Msg);
		delete UnrealReload;
		return;
		
	}
	if (NimHotReload->bShouldHotReload) {
	// if (!bIsFirstLoad) {
		NimForUESubsystem->EditorUtils = NewObject<UEditorUtils>();\
		NimForUESubsystem->EditorUtils->HotReload(NimHotReload, UnrealReload);
	
	}
	if (UnrealReload != nullptr)
		delete UnrealReload;
		// delete NimHotReload;

	// FCoreUObjectDelegates::ReloadCompleteDelegate.Broadcast(EReloadCompleteReason::HotReloadManual);

	
	UEditorUtils::ShowLoadNotification(bIsFirstLoad);
	UE_LOG(LogTemp, Log, TEXT("NimForUE just hot reloaded!! %s"), *Msg);
	NimForUESubsystem->ReloadTimes++;
}

void UNimForUEEngineSubsystem::CreateNimPackage() {
	NimForUEPackage = CreatePackage(TEXT("/Script/Nim"));
	NimForUEPackage->SetPackageFlags(PKG_CompiledIn);
	NimForUEPackage->SetFlags(RF_Standalone);
	NimForUEPackage->AddToRoot();

}

void UNimForUEEngineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	initializeHost();
	CreateNimPackage();
	auto onPreReload = [](NCSTRING msg) {
		// subscribeToReloadWorkaround until we have a proper HotReload Load/Unload mechanism
		// FNimTestBase::UnregisterAll();
	};
	auto onPostReload = [](NCSTRING msg) {
		LoadNimGuest(FString(msg));
	};
	
	subscribeToReload(onPreReload, onPostReload);
	
	checkReload();

	TickDelegateHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UNimForUEEngineSubsystem::Tick), 0.1);
}

void UNimForUEEngineSubsystem::Deinitialize()
{
	FTSTicker::GetCoreTicker().RemoveTicker(TickDelegateHandle);
}

bool UNimForUEEngineSubsystem::Tick(float DeltaTime)
{
	if (EditorUtils)
		EditorUtils->Tick(DeltaTime);
	checkReload();
	return true;
}
