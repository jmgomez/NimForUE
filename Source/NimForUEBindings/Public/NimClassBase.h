// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "UObject/Class.h"
#include "NimClassBase.generated.h"

/**
 * 
 */

//
//
// UCLASS()
// class NIMFORUEBINDINGS_API UNimEnum : public UEnum {
// GENERATED_BODY()
// public:
// 	FString ueType;
// 	UNimEnum(const FObjectInitializer& Initializer);
//
// 	TArray<TPair<FName, int64>> GetEnums();
// 	void MarkNewVersionExists(); 
// };

UCLASS()
class NIMFORUEBINDINGS_API UNimFunction : public UFunction {
	GENERATED_BODY()
public:
	//Stores a hash of the implementation of a function in nim so in the next compilation we can see if they are different so we can swap the fn pointer if they arent
	FString SourceHash; 
};

