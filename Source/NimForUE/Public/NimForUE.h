// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleInterface.h"


DECLARE_LOG_CATEGORY_EXTERN(NimForUE, Log, All);

class FNimForUEModule : public IModuleInterface
{
	void* NimForUEHandle = nullptr;
	void LoadNimForUEHost();
	void UnloadNimForUEHost();
public:
	inline static int ReloadTimes = 0;
	/** IModuleInterface implementation */
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
};
