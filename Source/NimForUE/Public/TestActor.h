// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/DataTable.h"
#include "TestActor.generated.h"

USTRUCT(BlueprintType)
struct FMyStructTableRow : public FTableRowBase {
	GENERATED_BODY()
		UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = Input)
		float TurnRateGamepad;
		UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = Input)
		UObject* ObjectTest;
	 
};


UCLASS(BlueprintType, meta=(BlueprintSpawnableComponent))
class UMyTestActorComponent : public UActorComponent {
	GENERATED_BODY()
public:
	
};

UENUM()
enum EMyTestRegularEnum
{
	OneValue,
	TwoValues,
	ThreeValues
};

UENUM()
enum class EMyTestEnumClass
{
	OneClassValue,
	AnotherClassValue,
	AnotherMore
};

UCLASS(BlueprintType, Blueprintable)
class NIMFORUE_API ATestActor : public AActor {
public:
	virtual bool IsListedInSceneOutliner() const override;

private:
	GENERATED_BODY()
	bool bTickCalled = false;
public:
	// Sets default values for this actor's properties
	ATestActor();
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	UMyTestActorComponent* TestActorComponentCpp;
protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;
	
public:
	// Called every frame
	virtual void Tick(float DeltaTime) override;
	UPROPERTY(EditAnywhere)
	class AStaticMeshActor* MeshActor;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TMap<int32, FString> RegularMap;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<int32> RegularArray;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FString> StrArray;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<UObject*> ObjArray;
	
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TMap<FString, UObject*> ObjMap;


	

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

	UFUNCTION(BlueprintCallable)
	void SetTestActorLocation(FVector NewLocation);

	UFUNCTION(CallInEditor)
	void ResetActorLocation();


	
};
