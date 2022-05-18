#pragma once
#include "CoreMinimal.h"
#include "NimForUEBindings.h"

//NON UE CPP Types binded to Nim.
class HelpersBindings {
public:
	static void NimForUELog(FString& Msg) {
		UE_LOG(NimForUEBindings, Log, TEXT("From Nim: %s"), *Msg);
	}
};
