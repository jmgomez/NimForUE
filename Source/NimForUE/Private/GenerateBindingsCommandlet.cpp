// Fill out your copyright notice in the Description page of Project Settings.


#include "GenerateBindingsCommandlet.h"

#include <NimForUEFFI.h>

#include "ReflectionHelpers.h"
#include "NimForUEEditor/NimForUEEditor.h"

#include "Misc/EngineVersionComparison.h"

UGenerateBindingsCommandlet::UGenerateBindingsCommandlet() {

}

int32 UGenerateBindingsCommandlet::Main(const FString& Params) {
#if WITH_EDITORONLY_DATA	
	UE_LOG(NimForUE, Display, TEXT("Hello from the command let!"));
	
	auto logger = [](NCSTRING msg) {
		UE_LOG(NimForUE, Log, TEXT("From NimForUEHostGenBindingsCommandlet): %s"), *FString(msg));
	};
	FGenericPlatformProcess::ConditionalSleep([]{return true;}, 2000);

	// registerLogger(logger);
#if UE_VERSION_OLDER_THAN(5, 5, 0)
	CommandletHelpers::TickEngine();
#endif
	// ensureGuestIsCompiled();
	checkReload(3); 
    genBindingsEntryPoint();
#endif
    return 0;
}
