// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "EditorUtils.generated.h"

/**
 * 
 */
UCLASS()
class NIMFORUEEDITOR_API UEditorUtils : public UObject {
	GENERATED_BODY()
public:
	static void RefreshNodes();
};