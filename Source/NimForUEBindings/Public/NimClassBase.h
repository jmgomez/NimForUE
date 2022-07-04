// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "NimClassBase.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEBINDINGS_API UNimClassBase : public UClass {
GENERATED_BODY()

virtual void Link(FArchive& Ar, bool bRelinkExistingProperties) override;
};
