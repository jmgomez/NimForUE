#include "../Public/NimForUEGame.h"
#include "CoreUObject/Public/UObject/UObjectGlobals.h"
DEFINE_LOG_CATEGORY(NimForUEGame);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"


constexpr char NUEModule[] = "some_module";

extern  "C" void startNue(uint8 calledFrom);
#if WITH_EDITOR

extern  "C" void* getGlobalEmitterPtr();
extern  "C" void reinstanceFromGloabalEmitter(void* globalEmitter);

#endif

void GameNimMain();

void StartNue() {
#if WITH_EDITOR
	FCoreUObjectDelegates::ReloadCompleteDelegate.AddLambda([&](EReloadCompleteReason Reason) {
	 UE_LOG(LogTemp, Log, TEXT("Reinstancing Lib"))
		GameNimMain();
		reinstanceFromGloabalEmitter(getGlobalEmitterPtr());
	});
#endif
	GameNimMain();
	startNue(1);
	// #endif
}



void FNimForUEGame::StartupModule()
{
  if (std::strcmp(NUEModule, "Bindings") != 0) {
	  StartNue();
  }
}

void FNimForUEGame::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FNimForUEGame, NimForUEGame)