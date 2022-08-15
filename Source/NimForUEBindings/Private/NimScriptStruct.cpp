// Fill out your copyright notice in the Description page of Project Settings.


#include "NimScriptStruct.h"

#include "Kismet2/ReloadUtilities.h"

void UNimScriptStruct::RegisterStructInDeferredList(ICppStructOps* StructOps)
{

	DeferCppStructOps(this->GetFName(), StructOps);

}

void UNimScriptStruct::PrepareCppStructOps() {
	if(GetName().Contains("Reinst") && this->CppStructOps == nullptr){
		check(CppStructOpsBackup)
		this->CppStructOps = CppStructOpsBackup;
		this->bPrepareCppStructOpsCompleted = true;
		return;
	}
	UScriptStruct::PrepareCppStructOps();
}
