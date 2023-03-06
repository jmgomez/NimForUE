// Copyright Epic Games, Inc. All Rights Reserved.

#include "NimForUE.h"
#include "Modules/ModuleManager.h"
#if WITH_EDITOR
	#include "Editor.h"
	#include "EditorUtils.h"
#include "NimForUEFFI.h"

#else
#include "NimForUEGame.h"
#endif
#include "Async/Async.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Widgets/Notifications/SNotificationList.h"
#include "Test/NimTestBase.h"

DEFINE_LOG_CATEGORY(NimForUE);

#include "Interfaces/IPluginManager.h"

#define LOCTEXT_NAMESPACE "FNimForUEModule"




#if WITH_STARTNUE
extern "C" N_LIB_PRIVATE N_CDECL(void, startNue)(void);
#endif

#if !WITH_EDITOR
N_CDECL(void, NimMain)(void);

#endif

void FNimForUEModule::StartupModule()
{
#if WITH_STARTNUE
	// If we are cooking we just skip
	 if (IsRunningCommandlet()) {
	 	NimMain();
	 	startNue();
	 	return;
	 }
#endif
#if WITH_EDITOR
#elif WITH_STARTNUE
	NimMain();
	startNue();
#endif
	
}

void FNimForUEModule::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)