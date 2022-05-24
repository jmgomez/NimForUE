// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include <stdbool.h>
#include "TestActor.generated.h"

UCLASS(BlueprintType, Blueprintable)
class NIMFORUE_API ATestActor : public AActor {
	GENERATED_BODY()

public:
	// Sets default values for this actor's properties
	ATestActor();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;
	
public:
	// Called every frame
	virtual void Tick(float DeltaTime) override;
	UPROPERTY(EditAnywhere)
	AStaticMeshActor* MeshActor;
	
	UFUNCTION(BlueprintCallable, CallInEditor, Category=NimForUE)
	static void PerformHotReload();
	
	UFUNCTION(BlueprintCallable, CallInEditor, Category = TestActor)
	static void CallUFuncFFI(UObject* Object);

	UFUNCTION()
	FString TestMultipleParams(FString Param1, int Number);

	UFUNCTION()
	bool BoolTestFromNimAreEquals(FString NumberStr, int Number, bool TestParam) {
		auto BoolToStr = [](bool Value){ return FString(Value?"True":"False");};
		UE_LOG(LogTemp, Log, TEXT("The value of the bool is %s"), *BoolToStr(TestParam));
		return TestParam;
		// bool ToReturn = NumberStr.Equals(FString::FromInt(Number)) && TestParam;
		// auto BoolToStr = [](bool Value){ return FString(Value?"True":"False");};
		// UE_LOG(LogTemp, Warning, TEXT("Str: %s Num: %d bool: %s, Return: %s"), *NumberStr, Number, *BoolToStr(TestParam), *BoolToStr(ToReturn));
		// return ToReturn;
	}
	UFUNCTION()
	void SaySomething(FString Msg);

	UFUNCTION()
	void SetColorByStringInMesh(FString Color);
};
