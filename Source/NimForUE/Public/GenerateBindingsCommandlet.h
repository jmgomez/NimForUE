// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "UObject/Object.h"
#include "GenerateBindingsCommandlet.generated.h"

//TODO Wrap it WithEditor. It's in here because we use host. Probably host needs to also live in the Editor module.

UCLASS()
class NIMFORUE_API UGenerateBindingsCommandlet : public UCommandlet {
	GENERATED_BODY()
public:
	UGenerateBindingsCommandlet();
	virtual int32 Main(const FString& Params) override;

};
