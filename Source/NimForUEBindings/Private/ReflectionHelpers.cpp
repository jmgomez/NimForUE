// Fill out your copyright notice in the Description page of Project Settings.


#include "ReflectionHelpers.h"

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
