// Fill out your copyright notice in the Description page of Project Settings.


#include "GenerateBindingsCommandlet.h"

#include <NimForUEFFI.h>

#include "ReflectionHelpers.h"
#include "NimForUEEditor/NimForUEEditor.h"

UGenerateBindingsCommandlet::UGenerateBindingsCommandlet() {

}

int32 UGenerateBindingsCommandlet::Main(const FString& Params) {
	UE_LOG(NimForUE, Display, TEXT("Hello from the command let!"));
	
	auto logger = [](NCSTRING msg) {
		UE_LOG(NimForUE, Log, TEXT("From NimForUEHostGenBindingsCommandlet): %s"), *FString(msg));
	};
	FGenericPlatformProcess::ConditionalSleep([]{return true;}, 2000);

	registerLogger(logger);
	CommandletHelpers::TickEngine();
	// ensureGuestIsCompiled();
	checkReload();
    genBindingsEntryPoint();
    return 0;
}
