#include "NimForUEAutoBindings.h"

#include "Modules/ModuleManager.h"
#include "UEGenBindings.h"

DEFINE_LOG_CATEGORY(NimForUEAutoBindings)
void NimForUEAutoBindingsModule::StartupModule() {
	// CreateClass(UObject::StaticClass(), "ClaseCreadaInBindings");
}

void NimForUEAutoBindingsModule::ShutdownModule() {
	IModuleInterface::ShutdownModule();
}
IMPLEMENT_MODULE(NimForUEAutoBindingsModule, NimForUEAutoBindings)



DLLEXPORT void testFunc2() {
	UE_LOG(NimForUEAutoBindings, Log, TEXT("testFunc2"));
	}