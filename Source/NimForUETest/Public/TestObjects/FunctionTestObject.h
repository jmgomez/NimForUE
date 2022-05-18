// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "FunctionTestObject.generated.h"


UCLASS()
class UMyReturnClass : public UObject {
	GENERATED_BODY()
public:
	bool bWasReturned = false;
	bool bWasModified = false;

	FString Saludo = "hola";
};

UCLASS()
class NIMFORUETEST_API UFunctionTestObject : public UObject {
	GENERATED_BODY()

public:
	bool bWasCalled = false;
	UFUNCTION()
	void ModifiedWasCalled();
	UFUNCTION()
	FString GetStringTwice(FString String);
	UFUNCTION()
	FString AddStrings(FString A, FString B);
	UFUNCTION()
	FString AddThreeStrings(FString A, FString B, FString C);

	UFUNCTION()
	FString ConvertIntToString(int N);

	UFUNCTION()
	int Add(int A, int B){ return A+B;}


	UFUNCTION()
	FString TestReturnStringWithParams(FString A, int B);
	UFUNCTION()
	void TestReturnStringWithParamsOut(FString A, int B, FString& Out);
	
	UFUNCTION()
	UMyReturnClass* MakeReturnClass() {
		auto Obj = NewObject<UMyReturnClass>();
		Obj->bWasReturned = true;
		return Obj;
	}
	UFUNCTION()
	void SendAsInput(UMyReturnClass* Obj) {
		Obj->bWasModified = true;
	}

	UFUNCTION()
	FString GetObjectNameNTimes(UObject* Obj, int Times) {
		FString ToReturn = "";
		UMyReturnClass* MyReturnClass = Cast<UMyReturnClass>(Obj);
		
		for(int i = 0; i<Times; i++) {
			ToReturn += MyReturnClass->Saludo;
		}
		return ToReturn;
	}
	UFUNCTION()
	FString GetObjectNameNTimes2(int Times, UObject* Obj, UObject* Obj2) {
		FString ToReturn = "";
		UMyReturnClass* MyReturnClass = Cast<UMyReturnClass>(Obj);
		
		for(int i = 0; i<Times; i++) {
			ToReturn += MyReturnClass->Saludo + Obj->GetName() + Obj2->GetName();
		}
		return ToReturn;
	}
	UFUNCTION()
	float SumFloats(float A, float B) {
		return A + B;
	}


	
};
