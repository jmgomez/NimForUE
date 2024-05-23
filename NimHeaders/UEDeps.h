
#pragma once

#ifndef WITH_ENGINE //Only include definitions is not coming from UBT
  #include "Definitions.NimForUEBindings.h"
#endif

#include "CoreMinimal.h"
#include "CoreUObject.h"
#include "EngineMinimal.h"

#include "Net/UnrealNetwork.h"

#include "Delegates/Delegate.h"

#include "Containers/UnrealString.h"
#include "Containers/Array.h"
#include "Engine/Engine.h" //TODO review headers because proibably most already pulled from this one
#include "CoreUObject.h"
#include "CoreUObjectSharedPCH.h" //Same as above


#include "Engine/AssetManager.h"
#include "Engine/DeveloperSettings.h"

#include "Animation/AnimNotifies/AnimNotify.h"
#include "Animation/AnimInstance.h"
#include "Animation/BlendProfile.h"
#include "Animation/AnimBlueprintGeneratedClass.h"
#include "GameFramework/Actor.h"
#include "GameFramework/Volume.h"
#include "GameFramework/GameSession.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/GameMode.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/WorldSettings.h"
#include "GameFramework/HUD.h"
#include "GameFramework/PlayerStart.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Engine/DataTable.h"
#include "Engine/Channel.h"
#include "Engine/SceneCapture.h"

#include "WorldPartition/DataLayer/DataLayerInstance.h"
#include "Engine/DamageEvents.h"
// #include "Private/AsyncActionLoadPrimaryAsset.h"
#include "Kismet/BlueprintAsyncActionBase.h"
#include "PreviewScene.h"


#include "Misc/AutomationTest.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/UserDefinedEnum.h"
#include "Components/ActorComponent.h"
#include "UObject/ConstructorHelpers.h"
#include "UObject/UObjectAllocator.h"
#include "UObject/ObjectSaveContext.h"

//Slate
#include "Widgets/Layout/Anchors.h"


//NimForUEBindingsHeaders.h
#include "NimForUEBindingsHeaders.h"
#include "../Source/NimForUE/Public/NimForUEHeaders.h"
//Editor only
//#include "FakeFactory.h"
#include "PhysicalMaterials/PhysicalMaterial.h"


#include "GameplayTagContainer.h"

#include "InputAction.h"
#include "InputActionValue.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"


#if WITH_EDITORONLY_DATA
  #include "Editor/UnrealEdEngine.h"
  #include "Editor/UnrealEd/Public/Editor.h"
  #include "Editor/UnrealEd/Public/EditorViewportClient.h"
  #include "Editor/UnrealEd/Public/SAssetEditorViewport.h"
  #include "Editor/UnrealEd/Public/LevelEditorViewport.h"
  #include "Editor/UnrealEd/Public/AssetEditorViewportLayout.h"
  #include "Editor/UnrealEd/Public/ScopedTransaction.h"
  #include "Factories/Factory.h"
  #include "WorkflowOrientedApp/WorkflowTabManager.h"
  #include "WorkflowOrientedApp/WorkflowTabFactory.h"
  #include "SCommonEditorViewportToolbarBase.h"

  #include "AdvancedPreviewScene.h"
  #include "SAdvancedPreviewDetailsTab.h"
  //asset tools
  #include "AssetTypeActions_Base.h"

#endif
#include "Components/Widget.h"
#include "Components/Viewport.h"
#include "Widgets/Docking/SDockTab.h"


//TEMP test 52
//TODO add with ENGINE_
//NOTE: The includes come from NimForUEBindinds!!
#include "AbilitySystemGlobals.h"
#include "AbilitySystemComponent.h"
#include "ABilitySystemInterface.h"
#include "Abilities/Tasks/AbilityTask.h"
#include "NavigationSystem.h"

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


#if  ENGINE_MINOR_VERSION >= 4
#include "EnhancedInput/Public/InputMappingQuery.h"
#include "EnhancedInput/Public/EnhancedActionKeyMapping.h"
#include "PhysicsEngine/ConstraintInstance.h"

#endif



// #include "UPropertyCaller.h"


#include "UEInterop.h"