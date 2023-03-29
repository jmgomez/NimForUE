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




#if !WITH_EDITOR
N_CDECL(void, NimMain)(void);

#endif

void FNimForUEModule::StartupModule()
{

	
}

void FNimForUEModule::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FNimForUEModule, NimForUE)