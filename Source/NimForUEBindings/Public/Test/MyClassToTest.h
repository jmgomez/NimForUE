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


DECLARE_DYNAMIC_DELEGATE_OneParam(FDynamicDelegateOneParamTest, FString, TestParam1);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDynamicMulticastDelegateOneParamTest, FString, TestParam1);
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

	UPROPERTY()
	TMap<FString, int32> MapProperty;

	UPROPERTY()
	FName NameProperty;

	UPROPERTY()
	FDynamicDelegateOneParamTest DynamicDelegateOneParamProperty;
	UPROPERTY()
	FDynamicMulticastDelegateOneParamTest MulticastDynamicDelegateOneParamProperty;
	
	UPROPERTY()
	bool bWasCalled;
	UFUNCTION()
	void BindDelegateFuncToMultcasDynOneParam() {
		MulticastDynamicDelegateOneParamProperty.AddDynamic(this, &UMyClassToTest::DelegateFunc);
	}
	UFUNCTION()
	void BindDelegateFuncToDelegateOneParam() {
		// DynamicDelegateOneParamProperty.BindDynamic(this, &UMyClassToTest::DelegateFunc);
		TScriptDelegate<>* ScriptDel = &DynamicDelegateOneParamProperty;
		// DynamicDelegateOneParamProperty.
		// TBaseDynamicDelegate<FWeakObjectPtr, void, FString> Del;
		// DynamicDelegateOneParamProperty = Del;
		ScriptDel->BindUFunction(this, FName("DelegateFunc"));
		
	}
	
	UFUNCTION()
	void DelegateFunc(FString Par) {
		bWasCalled = true;
		UE_LOG(LogTemp, Warning, TEXT("Delegate Func Called. The param is %s"), *Par);
	}
	
	UFUNCTION()
	FString GetHelloWorld() {
		FStructToUseAsVar::StaticStruct();
		
		return "Hello World!";
	}

	UFUNCTION()
	static FString GetHelloWorldStatic() { return "Hello World!";}
};
