// Fill out your copyright notice in the Description page of Project Settings.


#include "NimScriptStruct.h"

// UNimScriptStruct::UNimScriptStruct(UScriptStruct* InSuperStruct, SIZE_T ParamsSize, SIZE_T Alignment)
// 	: UScriptStruct(FObjectInitializer(), InSuperStruct) {
// 	OriginalStructOps = nullptr;
//
// }

UNimScriptStruct::UNimScriptStruct(const FObjectInitializer& ObjectInitializer, UScriptStruct* InSuperStruct,
	ICppStructOps* InCppStructOps, EStructFlags InStructFlags, SIZE_T ExplicitSize, SIZE_T ExplicitAlignment) :
UScriptStruct(ObjectInitializer, InSuperStruct, InCppStructOps, InStructFlags, ExplicitSize, ExplicitAlignment) {
	OriginalStructOps = InCppStructOps;
}

void UNimScriptStruct::PrepareCppStructOps() {
#if WITH_EDITORONLY_DATA
	// GIsUCCMakeStandaloneHeaderGenerator = true;
#endif
	UScriptStruct::PrepareCppStructOps();
	if(!CppStructOps) {
    		//If it fails after preparing it, it means it's already gonna away so we use our backup (and copy for the next usage)
    		void* StructOps = FMemory::Malloc(sizeof(ICppStructOps), alignof(ICppStructOps));
    		FMemory::Memcpy(StructOps, OriginalStructOps,sizeof(ICppStructOps));
    		CppStructOps = static_cast<ICppStructOps*>(StructOps);
    	}
#if WITH_EDITORONLY_DATA
	// GIsUCCMakeStandaloneHeaderGenerator = false;
#endif

}
