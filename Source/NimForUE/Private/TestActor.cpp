// Fill out your copyright notice in the Description page of Project Settings.


#include "TestActor.h"

#include "NimForUE.h"
#include "NimForUEFFI.h"
#include "Engine/StaticMeshActor.h"
#include "Kismet/KismetMathLibrary.h"
#include "Kismet/KismetStringLibrary.h"
#include "Kismet/KismetSystemLibrary.h"

// Sets default values
ATestActor::ATestActor() {
	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;
}

// Called when the game starts or when spawned
void ATestActor::BeginPlay() {
	Super::BeginPlay();
	
}

// Called every frame
void ATestActor::Tick(float DeltaTime) {
	Super::Tick(DeltaTime);
}

static bool init = false;

void ATestActor::CallUFuncFFI(UObject* Object) {
	testCallUFuncOn(Object);
}

void ATestActor::ReproduceStringIssue() { //Doesnt happen
}

FString ATestActor::TestMultipleParams(FString Param1, int Test) {
	//UE_LOG(LogTemp, Warning, TEXT("Call from Nim in Cpp"))
	return Param1.Append(FString::FromInt(Test));
}

bool ATestActor::BoolTestFromNimAreEquals(FString NumberStr, int Number, bool TestParam) {
	auto BoolToStr = [](bool Value){ return FString(Value?"True":"False");};
	//UE_LOG(LogTemp, Log, TEXT("The value of the bool is %s"), *BoolToStr(TestParam));
	return TestParam;
	
}

void ATestActor::SaySomething(FString Msg) {
	UKismetSystemLibrary::PrintString(this, Msg, true, false, FLinearColor::Blue, 0);
}

void ATestActor::SetColorByStringInMesh(FString ColorStr) {
	FLinearColor Color;
	bool bIsValid = Color.InitFromString(ColorStr);
	if(bIsValid && MeshActor && MeshActor->GetStaticMeshComponent()) {
		UStaticMeshComponent* MeshComp = MeshActor->GetStaticMeshComponent();
		MeshComp->SetVectorParameterValueOnMaterials(FName("Base Color"), UKismetMathLibrary::Conv_LinearColorToVector(Color));
	} else if(!bIsValid) {
		UKismetSystemLibrary::PrintString(this, FString::Printf(TEXT("Color Invalid %s"), *ColorStr), true, false, FLinearColor::Red, 2);
	}
}



