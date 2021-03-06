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
	class AStaticMeshActor* MeshActor;
	
	UFUNCTION(BlueprintCallable, CallInEditor, Category = TestActor)
	static void CallUFuncFFI(UObject* Object);

	UFUNCTION(BlueprintCallable, CallInEditor, Category = TestActor)
	static void CallInEditor();

	UFUNCTION(BlueprintCallable, CallInEditor, Category = TestActor)
	static void ReproduceStringIssue();

	UFUNCTION()
	FString TestMultipleParams(FString Param1, int Number);

	UFUNCTION()
	bool BoolTestFromNimAreEquals(FString NumberStr, int Number, bool TestParam);

	UFUNCTION()
	TArray<FString> TestArrays() {
		TArray<FString> ToReturn = { "Uno", "Dos", "Thre", "another"};
		
		return ToReturn;
	}
	UFUNCTION()
	void SaySomething(FString Msg);

	UFUNCTION()
	void SetColorByStringInMesh(FString Color);
};
