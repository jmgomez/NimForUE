// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"

#include "NimClassBase.generated.h"

/**
 * 
 */




UCLASS()
class NIMFORUEBINDINGS_API UNimClassBase : public UClass {
GENERATED_BODY()
public:
	void* UETypePtr;

	void SetClassConstructor(void (*NimClassConstructor) (FObjectInitializer&));

static UNimClassBase* GetFirstNimClassBase(UObject* Obj);

};

UCLASS()
class NIMFORUEBINDINGS_API UNimEnum : public UEnum {
GENERATED_BODY()
public:
	void* UETypePtr;
	UNimEnum(const FObjectInitializer& Initializer);

	TArray<TPair<FName, int64>> GetEnums();
	void MarkNewVersionExists(); 
};

UCLASS()
class NIMFORUEBINDINGS_API UNimFunction : public UFunction {
	GENERATED_BODY()
public:
	//Stores a hash of the implementation of a function in nim so in next compilation we can see if they are different so we can swap the fn pointer if they arent
	FString SourceHash; 
};

UCLASS()
class NIMFORUEBINDINGS_API UNimDelegateFunction : public UDelegateFunction {
	GENERATED_BODY()
public:
	void* UETypePtr;

};

