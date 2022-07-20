// Fill out your copyright notice in the Description page of Project Settings.


#include "NimClassBase.h"

UNimEnum::UNimEnum(const FObjectInitializer& Initializer) : UEnum(Initializer) {
	SetEnumFlags(EEnumFlags::Flags);
}
