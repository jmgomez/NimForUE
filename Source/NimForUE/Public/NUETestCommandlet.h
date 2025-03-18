// Fill out your copyright notice in the Description page of Project Settings.

#pragma once


#if PLATFORM_WINDOWS 
#include <NimForUEFFI.h>

extern  "C" void runNUETests();
#endif
#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "NUETestCommandlet.generated.h"

UCLASS()
class NIMFORUE_API UNUETestCommandlet : public UCommandlet {
	GENERATED_BODY()
	#if PLATFORM_WINDOWS 
	virtual int32 Main(const FString& Params) override;
	#endif

};
