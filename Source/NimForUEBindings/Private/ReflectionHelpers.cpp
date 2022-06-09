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

FProperty* UReflectionHelpers::GetFPropetyByName(UStruct* Struct, FString& Name) {
	for (TFieldIterator<FProperty> It(Struct); It; ++It) {
		FProperty* Prop = *It;
		if(Prop->GetName().Equals(Name)) {
			return Prop;
		}
	}
	return nullptr;

}
