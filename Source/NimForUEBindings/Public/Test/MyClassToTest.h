// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "MyClassToTest.generated.h"

/**
 * 
 */

DECLARE_DYNAMIC_DELEGATE_OneParam(FDynamicDelegateOneParamTest, FString, TestParam1);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDynamicMulticastDelegateOneParamTest, FString, TestParam1);

UENUM(BlueprintType)
enum EMyTestEnum {
	TestValue,
	TestValue2
};

UENUM()
enum class EMyTestEnum2 : uint16 {
	E2TestValue,
	E2TestValue2
};

USTRUCT(BlueprintType)
struct FStructToUseAsVar {
	GENERATED_BODY()
	UPROPERTY()
	FString TestProperty = "Hello World!";
	UPROPERTY(BlueprintReadWrite)
	TSubclassOf<AActor> ActorSubclass;
	UPROPERTY(BlueprintAssignable, BlueprintReadWrite)
	FDynamicMulticastDelegateOneParamTest Del;
	UPROPERTY(BlueprintAssignable)
	FDynamicMulticastDelegateOneParamTest Del2;
};

USTRUCT(BlueprintType)
struct FStructToUseAsVarDelTest {
	GENERATED_BODY()
	UPROPERTY()
	FString TestProperty = "Hello World!";
};


UCLASS(Blueprintable, BlueprintType)
class UMyClassToDeriveToTestUFunctions : public UObject {
	GENERATED_BODY()
public:
	
	UFUNCTION(BlueprintImplementableEvent)
	void ImplementableEventTest(const FString& Param);
	UFUNCTION()
	void ImplementableEventTest2Params(int32 Whaatever,FString Param);
	
	UFUNCTION()
	int32 ImplementableEventTestReturns(FString Param);
	
};
UCLASS(Blueprintable, BlueprintType)
class AUseClassToDeriveToTestFunction : public AActor {
	GENERATED_BODY()
public:
	
	UFUNCTION(BlueprintCallable)
	void TestCallFromCpp(UMyClassToDeriveToTestUFunctions* Object);
	
};

UCLASS(Blueprintable, BlueprintType)
class UClassToUseAsVar : public UObject {
	GENERATED_BODY()
public:
	UPROPERTY()
	FString TestProperty = "Im a valid var";
	UPROPERTY(BlueprintReadWrite)
	FDynamicMulticastDelegateOneParamTest Del;
	UPROPERTY(BlueprintAssignable, BlueprintCallable)
	FDynamicMulticastDelegateOneParamTest Del2;
};

UCLASS(Blueprintable, BlueprintType)
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
	TSoftClassPtr<UObject> SoftClassProperty;

	UPROPERTY()
	TMap<FString, int32> MapProperty;

	UPROPERTY()
	FName NameProperty;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FDynamicDelegateOneParamTest DynamicDelegateOneParamProperty;
	
	UPROPERTY(EditAnywhere, BlueprintAssignable, BlueprintReadWrite)
	FDynamicMulticastDelegateOneParamTest MulticastDynamicDelegateOneParamProperty;
	
	UPROPERTY()
	bool bWasCalled;
	UFUNCTION()
	void BindDelegateFuncToMultcasDynOneParam() {
		// MulticastDynamicDelegateOneParamProperty.AddDynamic(this, &UMyClassToTest::DelegateFunc);
		TMulticastScriptDelegate<>* MulScrip = &MulticastDynamicDelegateOneParamProperty;
		FScriptDelegate ScriptDel;
		ScriptDel.BindUFunction(this, FName("DelegateFunc"));
		
		MulScrip->AddUnique(ScriptDel);
	}
	UFUNCTION()
	void BindDelegateFuncToDelegateOneParam() {
		// DynamicDelegateOneParamProperty.BindDynamic(this, &UMyClassToTest::DelegateFunc);
		TScriptDelegate<>* ScriptDel = &DynamicDelegateOneParamProperty;
		ScriptDel->BindUFunction(this, FName("DelegateFunc"));
	}
	
	UFUNCTION()
	void DelegateFunc(FString Par) {
		bWasCalled = true;
		UE_LOG(LogTemp, Log, TEXT("Delegate Func Called. The param is %s"), *Par);
	}
	UFUNCTION()
	void FakeFunc() {}
	UFUNCTION()
	FString GetHelloWorld() {
		FStructToUseAsVar::StaticStruct();
		
		return "Hello World!";
	}

	UFUNCTION()
	static FString GetHelloWorldStatic() { return "Hello World!";}
};
