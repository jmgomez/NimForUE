#include "../Public/NimForUEGame.h"

DEFINE_LOG_CATEGORY(NimForUEGame);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"
extern "C" void startNue();
extern "C" void NimMain();
void FNimForUEGame::StartupModule()
{
	NimMain();
	startNue();
}

void FNimForUEGame::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FNimForUEGame, NimForUEGame)