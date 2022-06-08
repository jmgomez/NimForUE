// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "MyClassToTest.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEBINDINGS_API UMyClassToTest : public UObject {
	GENERATED_BODY()
public:
	UPROPERTY()
	FString TestProperty = "Hello World!";

	UPROPERTY()
	int32 IntProperty = 2;

	

	

	
	UFUNCTION()
	FString GetHelloWorld() {
		return "Hello World!";
	}

	UFUNCTION()
	static FString GetHelloWorldStatic() { return "Hello World!";}
};
