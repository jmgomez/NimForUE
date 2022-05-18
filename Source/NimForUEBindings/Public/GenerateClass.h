#pragma once

#include "AssetRegistry/AssetRegistryModule.h"
#include "Factories/BlueprintFactory.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "Kismet2/KismetReinstanceUtilities.h"





//TODO Investigate in depth another approach
inline void CreateClass(UClass* ParentClass, FString NewClassName) {
	UPackage* Package = CreatePackage(TEXT("/Game/Nim/"));

	//Dummy object to actually create the package for the GeneratedClass
	// UObject* Obj = NewObject<UPrimaryDataAsset>(Package, *FString("TestingAsset2"), EObjectFlags::RF_Public | EObjectFlags::RF_Standalone);
	// FAssetRegistryModule::AssetCreated(Obj);
	// Package->Save2()
	//TODO Non native, how to approach?
	/*TODO Find a way to dont generate two assets or at least:
		1. The blueprint one should not appear in the list to inherit
		2. The bluerpint one should not appear in the content browser (or use a proxy editor asset where we show Nim info and message informing of what it is).
	*/	

	//
	UClass* GeneratedClass = NewObject<UClass>(Package,  *(NewClassName),  RF_Public | RF_Standalone | RF_Transactional | RF_LoadCompleted );
	
	// UNimGeneratedClass* GeneratedClass = NewObject<UNimGeneratedClass>(Package,  *(NewClassName),  RF_Public | RF_Standalone | RF_Transactional | RF_LoadCompleted );
	FAssetRegistryModule::AssetCreated(GeneratedClass);
	
	// // Mark the package dirty...
	// // Package->MarkPackageDirty();
	// //
	// //
	// UBlueprint* Blueprint = FKismetEditorUtilities::CreateBlueprint(ParentClass, Package, *(NewClassName+"_BP"), BPTYPE_Normal, UBlueprint::StaticClass(), GeneratedClass, FName("NimBindings"));
	// Blueprint->Status = BS_BeingCreated;
	// Blueprint->BlueprintType = EBlueprintType::BPTYPE_Const;
	// Blueprint->ParentClass = ParentClass;
	// Blueprint->BlueprintSystemVersion = UBlueprint::GetCurrentBlueprintSystemVersion();
	// Blueprint->bIsNewlyCreated = true;
	// Blueprint->bLegacyNeedToPurgeSkelRefs = false;
	// //
	// //
	// FAssetRegistryModule::AssetCreated(Blueprint);
	// //
	// // // Mark the package dirty...
	// Package->MarkPackageDirty();
	//
	// //
	// // // Blueprint->BlueprintGuid = "s" it's a property if it's really necessary I could create one 
	// //
	// // //Handle native?
	// Blueprint->GeneratedClass = GeneratedClass;
	// //
	// GeneratedClass->ClassGeneratedBy = Blueprint;

	// GeneratedClass->ClassConstructor = [](const FObjectInitializer& ObjectInitializer) {
	// 	//Not sure what to do here
	//
	// 	//Call constructor in nim?
	//
	// };
	GeneratedClass->ClassConstructor = nullptr;

	// Set properties we need to regenerate the class with
	GeneratedClass->PropertyLink = ParentClass->PropertyLink;
	GeneratedClass->ClassWithin = ParentClass->ClassWithin;
	GeneratedClass->ClassConfigName = ParentClass->ClassConfigName;

	GeneratedClass->SetSuperStruct(ParentClass);
	GeneratedClass->ClassFlags |= (ParentClass->ClassFlags & (CLASS_Inherit | CLASS_ScriptInherit | CLASS_CompiledFromBlueprint | CLASS_HideDropDown));
	// GeneratedClass->ClassFlags = CLASS_HideDropDown; //(ParentClass->ClassFlags & (CLASS_Inherit | CLASS_ScriptInherit | CLASS_CompiledFromBlueprint | CLASS_HideDropDown));
	GeneratedClass->ClassCastFlags |= ParentClass->ClassCastFlags;

	// //Add functions?
	// UReflectionHelpers::AddUFunctionToClass(GeneratedClass);
	// //Add properties
	// UReflectionHelpers::CreatePropertyInClassBy(GeneratedClass, "TestProperty", "string");
	// UReflectionHelpers::CreatePropertyInClassBy(GeneratedClass, "TestProperty2", "string");
	// UReflectionHelpers::CreatePropertyInClassBy(GeneratedClass, "TestProperty3", "string");
	// UReflectionHelpers::CreatePropertyInClassBy(GeneratedClass, "TestProperty4", "string");
	// UReflectionHelpers::CreatePropertyInClassBy(GeneratedClass, "TestProperty5", "string");

	//SetMoreClassFlags

	GeneratedClass->Bind();
	GeneratedClass->StaticLink(true);
	
	//Here it also adds Others TMap<FString,Handle<Value>> Others;
	
	//Instanciate the CDO, it uses Archetype. Need to look into it
	GeneratedClass->GetDefaultObject();
	if (!GeneratedClass->HasAnyClassFlags(CLASS_TokenStreamAssembled)){
		GeneratedClass->AssembleReferenceTokenStream();
	}
	// FBlueprintCompileReinstancer::Create(GeneratedClass);
}



