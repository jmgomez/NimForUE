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
	virtual bool HasDestructor() override { return false; }

	virtual bool HasZeroConstructor() override { return false; }
	
	
};

UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()
		//Used when hot reloading as a backup so when the UEReloader cleans the previous, we can set this one in PrepareStruct. 
		ICppStructOps* CppStructOpsBackup;
		void RegisterStructInDeferredList(ICppStructOps* StructOps);
public:
	FString ueType;
	template<typename T>
	void SetCppStructOpFor(T* FakeType) {
		auto StructOps = new TNimCppStructOps<T>();
		RegisterStructInDeferredList(StructOps);
		CppStructOpsBackup = StructOps;
		this->CppStructOps = StructOps;
	}

	virtual void PrepareCppStructOps() override;
	
};
