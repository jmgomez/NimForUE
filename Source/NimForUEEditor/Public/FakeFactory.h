// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Factories/Factory.h"
#include "UObject/Object.h"
#include "FakeFactory.generated.h"


//TODO this should live in an editor module 
UCLASS()
class NIMFORUEEDITOR_API UFakeFactory : public UFactory {
	GENERATED_BODY()

public:
	
	UFUNCTION()
	static void BroadcastAsset(UObject* AssetToBroadcast);
};
