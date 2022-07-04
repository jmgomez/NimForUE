// Fill out your copyright notice in the Description page of Project Settings.


#include "NimClassBase.h"

void UNimClassBase::Link(FArchive& Ar, bool bRelinkExistingProperties) {
	//Jumps the check
	UStruct::Link(Ar, bRelinkExistingProperties);
}
