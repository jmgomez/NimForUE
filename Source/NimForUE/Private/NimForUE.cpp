// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"
#include "Modules/ModuleManager.h"
#if WITH_EDITOR
	#include "Editor.h"
#else
#endif

DEFINE_LOG_CATEGORY(NimForUE);

#define LOCTEXT_NAMESPACE "FNimFoUEModule"


void FNimForUEModule::StartupModule()
{

	
}

void FNimForUEModule::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)