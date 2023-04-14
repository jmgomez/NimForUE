#include "../Public/NimForUEGame.h"
#include "CoreUObject/Public/UObject/UObjectGlobals.h"
DEFINE_LOG_CATEGORY(NimForUEGame);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"
extern "C" void startNue(uint8 calledFrom);
void NimMain();
/*
*  NueLoadedFrom* {.size:sizeof(uint8), exportc .} = enum
	nlfPreEngine = 0, #before the engine is loaded, when the plugin code is registered.
	nlfPostDefault = 1, #after all modules are loaded (so all the types exists in the reflection system) this is also hot reloads. Should attempt to emit everything, layers before and after
	nlfEditor = 2 # Dont act different as loaded. Just Livecoding
	nlfCommandlet = 3 #while on the commandlet. Nothing special. Dont act different as loaded 

 */

void FNimForUEGame::StartupModule()
{
	FCoreUObjectDelegates::ReloadCompleteDelegate.AddLambda([&](EReloadCompleteReason Reason) {
		// BeginReload(ActiveReloadType, IReload& Interface)
		// UE_LOG(LogTemp, Log, TEXT("LC reason: $s"))
		startNue(2);
		
	});
// #if !WITH_EDITOR
	NimMain();
	startNue(1);
// #endif
}

void FNimForUEGame::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FNimForUEGame, NimForUEGame)