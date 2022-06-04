// Fill out your copyright notice in the Description page of Project Settings.


#include "ReflectionHelpers.h"

UClass* UReflectionHelpers::GetClassByName(FString ClassName) {
	UObject* ClassPackage = ANY_PACKAGE;
	UClass* Class = FindObject<UClass>(ClassPackage, *ClassName);
	// UClass* Class = LoadClass<UClass>(ClassPackage, *ClassName);
	return Class;
}

UObject* UReflectionHelpers::NewObjectFromClass(UClass* Class) {
	// UObject* Outer, FName Name, EObjectFlags Flags = RF_NoFlags, UObject* Template = nullptr,
	FStaticConstructObjectParameters Params(Class);
	Params.Outer = GetTransientPackage();
	Params.Name = NAME_None;
	Params.SetFlags = RF_NoFlags;
	Params.Template = nullptr;
	Params.bCopyTransientsFromClassDefaults = false;
	Params.InstanceGraph = nullptr;
	Params.ExternalPackage = nullptr;
	return (StaticConstructObject_Internal(Params));
}
