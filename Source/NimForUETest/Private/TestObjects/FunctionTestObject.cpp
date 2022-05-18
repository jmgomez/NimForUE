// Fill out your copyright notice in the Description page of Project Settings.


#include "NimForUETest/Public/TestObjects/FunctionTestObject.h"


void UFunctionTestObject::ModifiedWasCalled() {
	this->bWasCalled = true;
}

FString UFunctionTestObject::GetStringTwice(FString String) {
	return String + String;
}

FString UFunctionTestObject::AddStrings(FString A, FString B) {
	return A + B;
}

FString UFunctionTestObject::AddThreeStrings(FString A, FString B, FString C) {
	return A+B+C;
}

FString UFunctionTestObject::ConvertIntToString(int N) {
	return FString::FromInt(N);
}

FString UFunctionTestObject::TestReturnStringWithParams(FString A, int B) {
	return A + FString::FromInt(B);
}

void UFunctionTestObject::TestReturnStringWithParamsOut(FString A, int B, FString& Out) {
	Out = A + FString::FromInt(B);
}

