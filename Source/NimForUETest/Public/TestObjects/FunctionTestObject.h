// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "FunctionTestObject.generated.h"


USTRUCT()
struct FMyStructParam {
	GENERATED_BODY()

	UPROPERTY()
	int TestProp;
};
USTRUCT()
struct FMyStructParamWithStr {
	GENERATED_BODY()

	UPROPERTY()
	int TestProp;

	UPROPERTY()
	FString StrProp;
};

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
	UFUNCTION()
	FString TestMultipleParams(FString Param1, int Test) {
		UE_LOG(LogTemp, Warning, TEXT("Call from Nim in Cpp"))
		return Param1.Append(FString::FromInt(Test));
	}
	UFUNCTION()
	bool OR(bool Param1, bool Param2) {
		return Param1 || Param2;
	}

	UFUNCTION()
	TArray<FString> ArrayIntsToArrayStrings(TArray<int> Ints) {
		TArray<FString> ToReturn = {};
		for(int N : Ints) {
			ToReturn.Add(FString::FromInt(N));
		}
		return ToReturn;
	}
	UFUNCTION()
	int ArrayLength(TArray<int> Ints) {
		return Ints.Num();
	}

	UFUNCTION()
	static int StaticArrayLength(TArray<int> Ints) {
		return Ints.Num();
	}

	
	UFUNCTION()
	FString Reduce(TArray<FString> Strs) {
		FString Result = "";
		for(FString Str : Strs)
			Result += Str;
		
		UE_LOG(LogTemp, Log, TEXT("REDUCE CALL %s"), *Result);
		return Result;
	}

	UFUNCTION()
	int GetValueFromStruct(FMyStructParam Struct) {
		return Struct.TestProp;
	}
		UFUNCTION()
	FString GetStrValueFromStruct(FMyStructParamWithStr Struct) {
		return Struct.StrProp;
	}

	
	UFUNCTION()
    bool BoolTestFromNimAreEquals(FString NumberStr, int Number, bool TestParam) {
    	auto BoolToStr = [](bool Value){ return FString(Value?"True":"False");};
    	UE_LOG(LogTemp, Log, TEXT("The value of the bool is %s"), *BoolToStr(TestParam));
    	return TestParam;
    	
    }
	
};
