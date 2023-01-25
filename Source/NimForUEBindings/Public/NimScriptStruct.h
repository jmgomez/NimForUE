// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/UserDefinedStruct.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"



UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()

	ICppStructOps* OriginalStructOps;//To be used as fallback for prepareStruct
public:
	// explicit UNimScriptStruct(UScriptStruct* InSuperStruct, SIZE_T ParamsSize = 0, SIZE_T Alignment = 0);
	//UNimScriptStruct(UStrøuct* InSuperStruct, SIZE_T ParamsSize = 0, SIZE_T Alignment = 0);
	NIMFORUEBINDINGS_API explicit UNimScriptStruct(const FObjectInitializer& ObjectInitializer, UScriptStruct* InSuperStruct, ICppStructOps* InCppStructOps = nullptr, EStructFlags InStructFlags = STRUCT_NoFlags, SIZE_T ExplicitSize = 0, SIZE_T ExplicitAlignment = 0);
	UNimScriptStruct(){};
	template<typename T>
	void SetCppStructOpFor(T* FakeObject) {
		// Now is final. If using it right away doesnt work or we find a missmatch (which we will probably do) we could reimplement it
		//Notice, since UE 5.1, we could even pass what we need from Nim directly alongside T or maybe even without it
		this->ClearCppStructOps();
		this->CppStructOps = new TCppStructOps<T>();
		this->OriginalStructOps = new TCppStructOps<T>();
		this->PrepareCppStructOps();
	}
	//We need to override this because the FReload reinstancer will
	//check for the ops of the previus struct and it wont be here because
	void PrepareCppStructOps() override;

	
};
