// Fill out your copyright notice in the Description page of Project Settings.


#include "NimScriptStruct.h"

void UNimScriptStruct::PrepareCppStructOps() {
	UScriptStruct::PrepareCppStructOps();
	if(!CppStructOps) {
		//If it fails after preparing it, it means it's already gonna away so we use our backup (and copy for the next usage)
		void* StructOps = FMemory::Malloc(sizeof(ICppStructOps), alignof(ICppStructOps));
		FMemory::Memcpy(StructOps, OriginalStructOps,sizeof(ICppStructOps));
		CppStructOps = static_cast<ICppStructOps*>(StructOps);
	}
}
