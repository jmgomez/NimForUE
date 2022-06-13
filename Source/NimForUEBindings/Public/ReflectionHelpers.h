// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "ReflectionHelpers.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEBINDINGS_API UReflectionHelpers : public UObject {
	GENERATED_BODY()
public:
	UFUNCTION(BlueprintCallable)
	static UClass* GetClassByName(FString ClassName);
	UFUNCTION(BlueprintCallable)
	static UScriptStruct* GetScriptStructByName(FString StructName);
	UFUNCTION(BlueprintCallable)
	static UStruct* GetUStructByName(FString StructName);

	template<typename T>
	static T* GetUTypeByName(FString StructName) {
		UObject* ClassPackage = ANY_PACKAGE;
		T* Struct = FindObject<T>(ClassPackage, *StructName);
		return Struct;
	}

	static UObject* NewObjectFromClass(UClass* Class);

	//Need to do UStruct version or it can also be passed over here somehow? It maybe as easy as just change the type from UClass to UStruct (since UClass derives from UStruct)
	static FProperty* GetFPropetyByName(UStruct* Struct, FString& Name);


	template<typename T>
	static UClass* FromSubclass(TSubclassOf<T> SubclassOf) {
		return SubclassOf;
	}
	template<typename T>
	static TSubclassOf<T> ToSubclass() {
		return T::StaticClass();
	}

	UFUNCTION(BlueprintCallable)
	UClass* TestComp() {
		return FromSubclass(ToSubclass<UObject>());
	}
	
};
