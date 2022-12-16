
#pragma once

#ifndef WITH_ENGINE //Only include definitions is not coming from UBT
  #include "Definitions.NimForUEBindings.h"
#endif

#include "CoreMinimal.h"
#include "CoreUObject.h"
#include "EngineMinimal.h"

#include "Delegates/Delegate.h"

#include "Containers/UnrealString.h"
#include "Containers/Array.h"
#include "Engine/EngineTypes.h"
#include "Engine/DeveloperSettings.h"
#include "Engine/Classes/GameFramework/Actor.h"
#include "Engine/Classes/GameFramework/Volume.h"
#include "Engine/Classes/GameFramework/GameSession.h"
#include "Engine/Classes/GameFramework/PlayerController.h"
#include "Engine/Classes/GameFramework/GameMode.h"
#include "Engine/Classes/GameFramework/GameModeBase.h"
#include "Engine/Classes/Engine/World.h"
#include "Engine/Classes/Engine/Engine.h"
#include "Engine/Classes/Engine/DataTable.h"
#include "Engine/Classes/Animation/BlendProfile.h"
#include "Misc/AutomationTest.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/UserDefinedEnum.h"
#include "Components/ActorComponent.h"
#include "UObject/ConstructorHelpers.h"

//NimForUEBindingsHeaders.h
#include "NimForUEBindingsHeaders.h"
#include "../Source/NimForUE/Public/NimForUEHeaders.h"
//Editor only
//#include "FakeFactory.h"




#include "InputAction.h"
#include "InputActionValue.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#ifdef WITH_EDITOR
  #include "Editor/UnrealEdEngine.h"
  #include "Editor/UnrealEd/Public/Editor.h"
  #include "Editor/UnrealEd/Public/EditorViewportClient.h"
#endif