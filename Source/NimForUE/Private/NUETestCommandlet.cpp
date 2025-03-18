// Fill out your copyright notice in the Description page of Project Settings.

#if PLATFORM_WINDOWS 
#include "NUETestCommandlet.h"

#include "../../../NimHeaders/NimForUEFFI.h"


int32 UNUETestCommandlet::Main(const FString& Params) {
	UE_LOG(NimForUE, Display, TEXT("Hello from the test command let!"));
	runNUETests();
	// NimMain();
	return 0;
}
#endif