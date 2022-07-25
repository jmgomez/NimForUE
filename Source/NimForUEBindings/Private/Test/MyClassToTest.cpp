// Fill out your copyright notice in the Description page of Project Settings.


#include "Test/MyClassToTest.h"

void UMyClassToDeriveToTestUFunctions::ImplementableEventTest2Params(int32 Whaatever, FString Param) {
}

int32 UMyClassToDeriveToTestUFunctions::ImplementableEventTestReturns(FString Param) {
	return 1;
}

int32 UMyClassToDeriveToTestUFunctions::TestFuncWithOut(FString Param, bool& outParam) {
	return 5;
}

int32 UMyClassToDeriveToTestUFunctions::TestFuncWithOut2(FString Param, TArray<FString>& Test) {
	return 10;
}

int UMyClassToDeriveToTestUFunctions::TestStatic(FString Param) {
	return 4;
}

// void UMyClassToDeriveToTestUFunctions::ImplementableEventTest(FString Param) {
// 	UE_LOG(LogTemp, Log, TEXT("ClassToDerivetoTEstFunction called from cpp"));
// }
void AUseClassToDeriveToTestFunction::TestCallFromCpp(UMyClassToDeriveToTestUFunctions* Object) {
	Object->ImplementableEventTest("Esto es from cpp");
}
