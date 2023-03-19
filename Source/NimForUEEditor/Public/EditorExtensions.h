// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Styling/SlateStyle.h"
#include "UObject/Object.h"
#include "EditorExtensions.generated.h"

/**
 * At some point all of this will be pure Nim
 */

class FStyle : public FSlateStyleSet {
public:
	FStyle();
	void Initialize();
// 	
// private:
// 	FTextBlockStyle NormalText;
};
UCLASS()
class NIMFORUEEDITOR_API UEditorExtensions : public UObject {
	GENERATED_BODY()
private:
	static bool bIsInit;
	FStyle* Style;
public:
	

	UFUNCTION(BlueprintCallable)
	static void AddReloadScriptButtom();

	void Init();

};
