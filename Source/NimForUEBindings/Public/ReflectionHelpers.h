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

	static UObject* NewObjectFromClass(UClass* Class);

};
