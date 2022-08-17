// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/UserDefinedStruct.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"
 
/**
 * 
 */


template<class T>
struct TNimCppStructOps : public UScriptStruct::TCppStructOps<T> {
	virtual bool HasIdentical() override
	{
		return false; //TODO review this. Identical means an equals operator, we should be able to generate it. (It seems that it needs to be implemented in the Identical overload)
	}
	virtual bool HasSerializer() override
	{
		return false;
	}

	virtual bool HasZeroConstructor() override
	{
		return false;
	}


	virtual bool Serialize(FArchive& Ar, void* Data) override
	{
		return false;
	}

	virtual bool HasPostSerialize() override
	{
		return false;
	}

	virtual void PostSerialize(const FArchive& Ar, void* Data) override
	{
	}

	virtual bool HasNetSerializer() override
	{
		return false;
	}

	virtual bool HasNetSharedSerialization() override
	{
		return false;
	}

	virtual bool NetSerialize(FArchive& Ar, class UPackageMap* Map, bool& bOutSuccess, void* Data) override
	{
		return false;
	}

	virtual bool HasNetDeltaSerializer()
	{
		return false;
	}

	virtual bool NetDeltaSerialize(FNetDeltaSerializeInfo& DeltaParms, void* Data) override
	{
		return false;
	}

	virtual bool HasPostScriptConstruct() override
	{
		return false;
	}

	virtual void PostScriptConstruct(void* Data) override
	{
	}

	virtual bool IsPlainOldData() override
	{
		return false;
	}

	virtual bool HasExportTextItem() override
	{
		return false;
	}

	virtual bool ExportTextItem(FString& ValueStr, const void* PropertyValue, const void* DefaultValue, class UObject* Parent, int32 PortFlags, class UObject* ExportRootScope) override
	{
		return false;
	}

	virtual bool HasImportTextItem() override
	{
		return false;
	}

	virtual bool ImportTextItem(const TCHAR*& Buffer, void* Data, int32 PortFlags, class UObject* OwnerObject, FOutputDevice* ErrorText) override
	{
		return false;
	}

	virtual bool HasAddStructReferencedObjects() override
	{
		return false;
	}

	virtual TPointerToAddStructReferencedObjects AddStructReferencedObjects() override
	{
		return nullptr;
	}

	virtual bool HasSerializeFromMismatchedTag() override
	{
		return false;
	}

	virtual bool SerializeFromMismatchedTag(struct FPropertyTag const& Tag, FArchive& Ar, void* Data) override
	{
		return false;
	}

	virtual bool HasGetTypeHash() override
	{
		return false;
	}

	virtual uint32 GetStructTypeHash(const void* Src) override
	{
		return 0;
	}

	virtual EPropertyFlags GetComputedPropertyFlags() const override
	{
		return CPF_None;
	}
	virtual bool HasDestructor() { return false; }
	
};

UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()
		//Used when hot reloading as a backup so when the UEReloader cleans the previous, we can set this one in PrepareStruct. 
		ICppStructOps* CppStructOpsBackup;
	void RegisterStructInDeferredList(ICppStructOps* StructOps);


public:
	UNimScriptStruct(const FObjectInitializer& ObjectInitializer);
	UNimScriptStruct* NewNimScriptStruct; //If ther
	virtual void InitializeStruct(void* Dest, int32 ArrayDim) const override;
	FString ueType;
	template<typename T>
	void SetCppStructOpFor(T* FakeObject) {
		
		auto StructOps = new TNimCppStructOps<T>();
		RegisterStructInDeferredList(StructOps);
		CppStructOpsBackup = StructOps;
		this->CppStructOps = StructOps;
	}

	virtual void PrepareCppStructOps() override;
	
};
