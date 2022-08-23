// Fill out your copyright notice in the Description page of Project Settings.


#include "NimScriptStruct.h"

#include "Kismet2/ReloadUtilities.h"



void UNimScriptStruct::RegisterStructInDeferredList(ICppStructOps* StructOps)
{

	DeferCppStructOps(this->GetFName(), StructOps);

}
//
// UNimScriptStruct::UNimScriptStruct(const FObjectInitializer& ObjectInitializer)
// {
// }
//
// void UNimScriptStruct::InitializeStruct(void* InDest, int32 ArrayDim) const
// {
// 	// UScriptStruct::InitializeStruct(Dest, ArrayDim);
// 	uint8* Dest = (uint8*)InDest;
// 	check(Dest);
//
// 	int32 Stride = GetStructureSize();
//
// 	//@todo UE optimize
// 	FMemory::Memzero(Dest, ArrayDim * Stride);
//
// 	int32 InitializedSize = 0;
// 	UScriptStruct::ICppStructOps* TheCppStructOps = GetCppStructOps();
// 	if (TheCppStructOps != NULL){
// 		InitializedSize = TheCppStructOps->GetSize();
// 		// here we want to make sure C++ and the property system agree on the size
// 		check(Stride == InitializedSize && PropertiesSize == InitializedSize);
// 	}
//
// 	if (PropertiesSize > InitializedSize)
// 	{
// 		bool bHitBase = false;
// 		for (FProperty* Property = PropertyLink; Property && !bHitBase; Property = Property->PropertyLinkNext)
// 		{
// 			if (!Property->IsInContainer(InitializedSize))
// 			{
// 				for (int32 ArrayIndex = 0; ArrayIndex < ArrayDim; ArrayIndex++)
// 				{
// 					Property->InitializeValue_InContainer(Dest + ArrayIndex * Stride);
// 				}
// 			}
// 			else
// 			{
// 				bHitBase = true;
// 			}
// 		}
// 	}
// }
//
// void UNimScriptStruct::DestroyStruct(void* Dest, int32 ArrayDim) const
// {
// 	//Our structs has no destructors
// }

// void UNimScriptStruct::PrepareCppStructOps() {
	// if(NewNimScriptStruct && NewNimScriptStruct->bPrepareCppStructOpsCompleted) {
	// 	CppStructOps = NewNimScriptStruct->CppStructOps;
	// 	bPrepareCppStructOpsCompleted = true;
	// 	return;
	// }
	//
	// if(CppStructOps == nullptr){
	// 	check(CppStructOpsBackup)
	// 	CppStructOps = CppStructOpsBackup;
	// 	bPrepareCppStructOpsCompleted = true;
	// 	return;
	// }
	// Super::PrepareCppStructOps();
// }
