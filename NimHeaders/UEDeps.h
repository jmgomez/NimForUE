#pragma once

#ifndef WITH_ENGINE //Only include definitions is not coming from UBT
  #include "Definitions.NimForUEBindings.h"
#endif

#include "CoreMinimal.h"
#include "CoreUObject.h"

#include "Containers/UnrealString.h"
#include "Containers/Array.h"
#include "Engine/EngineTypes.h"
#include "Engine/DeveloperSettings.h"
#include "Engine/Classes/GameFramework/Volume.h"
#include "Engine/Classes/GameFramework/GameSession.h"
#include "Engine/Classes/Engine/World.h"
#include "Misc/AutomationTest.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/UserDefinedEnum.h"
#include "Components/ActorComponent.h"


//NimForUEBindingsHeaders.h
#include "NimForUEBindingsHeaders.h"
//Editor only
//#include "FakeFactory.h"
