// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()

public:
	template<typename T>
	void SetCppStructOpFor(T* FakeType) {
		this->CppStructOps = new UScriptStruct::TCppStructOps<T>();
	}
};
