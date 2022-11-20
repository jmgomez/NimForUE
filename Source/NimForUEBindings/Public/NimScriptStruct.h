// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/UserDefinedStruct.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"



UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()

public:
	template<typename T>
	void SetCppStructOpFor(T* FakeObject) {
		// Now is final. If using it right away doesnt work or we find a missmatch (which we will probably do) we could reimplement it
		//Notice, since UE 5.1, we could even pass what we need from Nim directly alongside T or maybe even without it
		this->CppStructOps = new TCppStructOps<T>();
		this->bPrepareCppStructOpsCompleted = false;
		this->PrepareCppStructOps();
	}



	
};
