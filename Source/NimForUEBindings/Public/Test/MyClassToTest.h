// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "MyClassToTest.generated.h"

/**
 * 
 */

UENUM()
enum EMyTestEnum {
	TestValue,
	TestValue2
};

USTRUCT()
struct FStructToUseAsVar {
	GENERATED_BODY()
	UPROPERTY()
	FString TestProperty = "Hello World!";
};

UCLASS()
class UClassToUseAsVar : public UObject {
	GENERATED_BODY()
public:
	UPROPERTY()
	FString TestProperty = "Im a valid var";
};

UCLASS()
class NIMFORUEBINDINGS_API UMyClassToTest : public UObject {
	GENERATED_BODY()
public:
	UPROPERTY()
	FString TestProperty = "Hello World!";

	UPROPERTY()
	int32 IntProperty = 2;

	UPROPERTY()
	float FloatProperty;

	UPROPERTY()
	bool BoolProperty;

	UPROPERTY()
	TArray<FString> ArrayProperty;

	UPROPERTY()
	UClassToUseAsVar* ObjectProperty;

	UPROPERTY()
	FStructToUseAsVar StructProperty;

	UPROPERTY()
	UClass* ClassProperty;

	UPROPERTY()
	TSubclassOf<UObject> SubclassOfProperty;

	UPROPERTY()
	TEnumAsByte<EMyTestEnum> EnumProperty;

	UPROPERTY()
	TSoftObjectPtr<UObject> SoftObjectProperty;
	
	UFUNCTION()
	FString GetHelloWorld() {
		FStructToUseAsVar::StaticStruct();
		return "Hello World!";
	}

	UFUNCTION()
	static FString GetHelloWorldStatic() { return "Hello World!";}
};
