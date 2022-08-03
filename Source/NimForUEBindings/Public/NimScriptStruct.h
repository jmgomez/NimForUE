// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"

/**
 * 
 */


template<class T>
struct TNimCppStructOps : public UScriptStruct::TCppStructOps<T> {
	virtual bool HasZeroConstructor() override {
		return false;
	}

};

UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()

public:
	void* UETypePtr;
	template<typename T>
	void SetCppStructOpFor(T* FakeType) {
		auto StructOps = new TCppStructOps<T>();
		
		this->CppStructOps = new TNimCppStructOps<T>();
	}

};
