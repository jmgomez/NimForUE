#include "NimForUEBindings.h"

#include "GenerateClass.h"
#include "Modules/ModuleManager.h"

DEFINE_LOG_CATEGORY(NimForUEBindings)
void NimForUEBindingsModule::StartupModule() {
	// CreateClass(UObject::StaticClass(), "ClaseCreadaInBindings");
}

void NimForUEBindingsModule::ShutdownModule() {
	IModuleInterface::ShutdownModule();
}
IMPLEMENT_MODULE(NimForUEBindingsModule, NimForUEBindings)