// Fill out your copyright notice in the Description page of Project Settings.


#include "ReflectionHelpers.h"

#include "NimForUEBindings.h"
#include "Interfaces/IPluginManager.h"


UClass* UReflectionHelpers::GetClassByName(FString ClassName) {
	UObject* ClassPackage = ANY_PACKAGE;
	UClass* Class = FindObject<UClass>(ClassPackage, *ClassName);
	return Class;
}

UScriptStruct* UReflectionHelpers::GetScriptStructByName(FString StructName) {
	UObject* ClassPackage = ANY_PACKAGE;
	UScriptStruct* Struct = FindObject<UScriptStruct>(ClassPackage, *StructName);
	return Struct;
}

UStruct* UReflectionHelpers::GetUStructByName(FString StructName) {
	UObject* StructPackage = ANY_PACKAGE;
	// TMap<int, int> M;
	// M.GenerateValueArray()
	UStruct* Struct = FindObject<UStruct>(StructPackage, *StructName);
	return Struct;
}

UObject* UReflectionHelpers::NewObjectFromClass(UObject* Owner, UClass* Class, FName Name) {
	// UObject* Outer, FName Name, EObjectFlags Flags = RF_NoFlags, UObject* Template = nullptr,
	FStaticConstructObjectParameters Params(Class);
	Params.Outer = Owner == nullptr ? GetTransientPackage() : Owner;
	Params.Name = Name;
	Params.SetFlags = RF_NoFlags;
	Params.Template = nullptr;
	Params.bCopyTransientsFromClassDefaults = false;
	Params.InstanceGraph = nullptr;
	Params.ExternalPackage = nullptr;
	return (StaticConstructObject_Internal(Params));
}

UObject* UReflectionHelpers::NewObjectFromClass(FStaticConstructObjectParameters Params) {
	return (StaticConstructObject_Internal(Params));
}

FProperty* UReflectionHelpers::GetFPropetyByName(UStruct* Struct, FString& Name) {
	for (TFieldIterator<FProperty> It(Struct); It; ++It) {
		FProperty* Prop = *It;
		if(Prop->GetName().Equals(Name)) {
			return Prop;
		}
	}
	return nullptr;

}

TArray<FProperty*> UReflectionHelpers::GetFPropertiesFrom(UStruct* Struct) {
	TArray<FProperty*> Props = {};
	for (TFieldIterator<FProperty> It(Struct); It; ++It) {
		Props.Add(*It);	
	}
	return Props;
	
}

void UReflectionHelpers::IncreaseStack(FFrame& Stack) {
	Stack.Code += !!Stack.Code; /* increment the code ptr unless it is null */
}

FString UReflectionHelpers::GetCppType(FProperty* Property) {
	return Property->GetCPPType();
}

TArray<UClass*> UReflectionHelpers::GetAllClassesFromModule(FString ModuleName) {
	//Should I grab only native classes?
	FString ModulePackageName = FPackageName::ConvertToLongScriptPackageName(*ModuleName);
	UPackage* Package = FindObjectFast<UPackage>(NULL, *ModulePackageName, false, false);
	// TObjectIterator<UClass> It (Package)
	if(!Package) return {};
	TArray<UClass*> Classes = {};
	ForEachObjectWithPackage(Package, [&](UObject* Object) {
		if(UClass* Class = Cast<UClass>(Object))
			Classes.Add(Class);
			return true;
		});
	return Classes;
}

UWorld* UReflectionHelpers::GetCurrentActiveWorld()
{
	UWorld* world = nullptr;
#if WITH_EDITOR
	if (GIsEditor)
	{
		if (GPlayInEditorID == -1)
		{
			FWorldContext* worldContext = GEditor->GetPIEWorldContext(1);
			if (worldContext == nullptr)
			{
				if (UGameViewportClient* viewport = GEngine->GameViewport)
				{
					world = viewport->GetWorld();
				}
			}
			else
			{
				world = worldContext->World();
			}
		}
		else
		{
			FWorldContext* worldContext = GEditor->GetPIEWorldContext(GPlayInEditorID);
			if (worldContext == nullptr)
			{
				return nullptr;
			}
			world = worldContext->World();
		}
	}
	else
	{
		world = GEngine->GetCurrentPlayWorld(nullptr);
	}

#else
	world = GEngine->GetCurrentPlayWorld(nullptr);
#endif
	return world;
}

void UReflectionHelpers::NimForUELog(FString Msg) {
	UE_LOG(NimForUEBindings, Log, TEXT("%s"), *Msg);
}

void UReflectionHelpers::NimForUEWarn(FString Msg) {
	UE_LOG(NimForUEBindings, Warning, TEXT("%s"), *Msg);

}

void UReflectionHelpers::NimForUEError(FString Msg) {
	UE_LOG(NimForUEBindings, Error, TEXT("%s"), *Msg);

}

TArray<FString> UReflectionHelpers::GetEnums(UEnum* Enum)
{
	int Values = Enum->NumEnums();
	TArray<FString> Names;
	Names.Reserve(Values);
	
	for (int i = 0; i < Values; i++) {
		Names.Add(Enum->GetNameStringByIndex(i));
	}
	return Names;
	
}

TArray<FString> UReflectionHelpers::GetAllModuleDepsForPlugin(FString PluginName) {
	//Not sure if this would work when not building against the editor
	auto Plugin = IPluginManager::Get().FindPlugin(PluginName);
	TArray<FString> Modules = {};
	if (Plugin.IsValid()) {
		for(FModuleDescriptor ModuleDescriptor : Plugin->GetDescriptor().Modules) {
			Modules.Add(ModuleDescriptor.Name.ToString());
		}
	}
	return Modules;
}

UPackage* UReflectionHelpers::CreateNimPackage(FString PackageShortName) {
	auto NimForUEPackage = CreatePackage(*FString::Printf(TEXT("/Script/%s"), *PackageShortName));
	NimForUEPackage->SetPackageFlags(PKG_CompiledIn);
	NimForUEPackage->SetFlags(RF_Standalone);
	NimForUEPackage->AddToRoot();
	return NimForUEPackage;
}


