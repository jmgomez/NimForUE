
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
#include "Engine/Engine.h" //TODO review headers because proibably most already pulled from this one
#include "CoreUObject.h"
#include "CoreUObjectSharedPCH.h" //Same as above


#include "Engine/AssetManager.h"
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
#include "Engine/Classes/Engine/SceneCapture.h"
#include "Engine/Public/WorldPartition/DataLayer/DataLayerInstance.h"
#include "Engine/DamageEvents.h"

#include "Misc/AutomationTest.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/UserDefinedEnum.h"
#include "Components/ActorComponent.h"
#include "UObject/ConstructorHelpers.h"
#include "UObject/UObjectAllocator.h"
#include "UObject/ObjectSaveContext.h"

//NimForUEBindingsHeaders.h
#include "NimForUEBindingsHeaders.h"
#include "../Source/NimForUE/Public/NimForUEHeaders.h"
//Editor only
//#include "FakeFactory.h"
#include "PhysicsCore/Public/PhysicalMaterials/PhysicalMaterial.h"


#include "GameplayTags/Classes/GameplayTagContainer.h"

#include "InputAction.h"
#include "InputActionValue.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"


#if WITH_EDITORONLY_DATA
  #include "Editor/UnrealEdEngine.h"
  #include "Editor/UnrealEd/Public/Editor.h"
  #include "Editor/UnrealEd/Public/EditorViewportClient.h"
  #include "Editor/UnrealEd/Public/LevelEditorViewport.h"

  #include "NavigationSystem.h"

#endif


//TEMP test 52
//TODO add with ENGINE_
//NOTE: The includes come from NimForUEBindinds!!
#include "AbilitySystemGlobals.h"

#if  ENGINE_MINOR_VERSION >= 2   
#include "Elements/PCGExecuteBlueprint.h"
#include "PCGContext.h"
#include "PCGElement.h"
#include "PCGComponent.h"
#include "PCGSubgraph.h"
#include "PCGSubsystem.h"
#include "PCGData.h"
#include "Data/PCGSpatialData.h"
#endif


// #include "UPropertyCaller.h"