// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/UserDefinedStruct.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"

class UNimScriptStruct;

template<typename T>
struct NimStructOps : UScriptStruct::ICppStructOps
{
	
	UNimScriptStruct* Struct;
	T Default;


	NimStructOps(UNimScriptStruct* InStruct) :
		Struct(InStruct),
		ICppStructOps(sizeof(T), alignof(T)) {
	}

	bool HasNoopConstructor() override
	{
		return false;
	}

	bool HasZeroConstructor() override
	{
		return false;
	}

	void Construct(void* Dest) override {
		*(static_cast<T*>(Dest)) = *(new T());
	}
	virtual void ConstructForTests(void* Dest) override
	{
		Construct(Dest);
	}

	bool HasDestructor() override
	{
		return false;
	}

	void Destruct(void* Dest) override {
		//Doesnt have destructor so this shouldnt be called
		FMemory::Memzero(Dest, GetSize());
	}

	bool HasCopy() override {
		return true;
	}

	bool Copy(void* Dest, void const* Src, int32 ArrayDim) override {
		T const * Source = reinterpret_cast<T const*>(Src);
		*(static_cast<T*>(Dest)) = *(Source);
		return true;
	}

	bool HasIdentical() override {
		return false; //vNext
	}

	bool Identical(const void* A, const void* B, uint32 PortFlags, bool& bOutResult) override {

		return false;
	}

	bool HasSerializer() override {
		return false;
	}

	bool Serialize(FArchive& Ar, void* Data) override {
		return false;
	}

	bool HasPostSerialize() override {
		return false;
	}

	void PostSerialize(const FArchive& Ar, void* Data) override {
	}

	bool HasNetSerializer() override {
		return false;
	}

	bool HasNetSharedSerialization() override {
		return false;
	}

	bool NetSerialize(FArchive& Ar, class UPackageMap* Map, bool& bOutSuccess, void* Data) override {
		return false;
	}

	bool HasNetDeltaSerializer() {
		return false;
	}

	bool NetDeltaSerialize(FNetDeltaSerializeInfo& DeltaParms, void* Data) override
	{
		return false;
	}

	bool HasPostScriptConstruct() override
	{
		return false;
	}

	void PostScriptConstruct(void* Data) override
	{
	}

	bool IsPlainOldData() override
	{
		return false;
	}

	bool HasExportTextItem() override
	{
		return false;
	}

	bool ExportTextItem(FString& ValueStr, const void* PropertyValue, const void* DefaultValue, class UObject* Parent, int32 PortFlags, class UObject* ExportRootScope) override
	{
		return false;
	}

	bool HasImportTextItem() override
	{
		return false;
	}

	bool ImportTextItem(const TCHAR*& Buffer, void* Data, int32 PortFlags, class UObject* OwnerObject, FOutputDevice* ErrorText) override
	{
		return false;
	}

	bool HasAddStructReferencedObjects() override
	{
		return false;
	}

	virtual TPointerToAddStructReferencedObjects AddStructReferencedObjects() override
	{
		return nullptr;
	}

	bool HasSerializeFromMismatchedTag() override
	{
		return false;
	}

	bool SerializeFromMismatchedTag(struct FPropertyTag const& Tag, FArchive& Ar, void* Data) override
	{
		return false;
	}

	bool HasGetTypeHash() override
	{
		return false;
	}

	uint32 GetStructTypeHash(const void* Src) override
	{
		return 0;
	}

	EPropertyFlags GetComputedPropertyFlags() const override
	{
		return CPF_None;
	}

	bool IsAbstract() const override
	{
		return false;
	}

	void GetCppTraits(bool& OutHasConstructor, bool& OutHasDestructor, bool& OutHasAssignmentOperator, bool& OutHasCopyConstructor) const
	{
		OutHasConstructor = true;
		OutHasDestructor = false;
		OutHasAssignmentOperator = true;
		OutHasCopyConstructor = true;
	}

	bool HasStructuredSerializer() override
	{
		return false;
	}

	bool HasStructuredSerializeFromMismatchedTag() override
	{
		return false;
	}

	bool Serialize(FStructuredArchive::FSlot Slot, void* Data) override
	{
		return false;
	}

	bool StructuredSerializeFromMismatchedTag(struct FPropertyTag const& Tag, FStructuredArchive::FSlot Slot, void* Data) override
	{
		return false;
	}

	bool IsUECoreType() override
	{
		return false;
	}

	bool IsUECoreVariant() override
	{
		return false;
	}

	void GetPreloadDependencies(void* Data, TArray<UObject*>& OutDeps) override
	{
	}
};

//ENDS NimStructOps


UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()
		//Used when hot reloading as a backup so when the UEReloader cleans the previous, we can set this one in PrepareStruct. 
	// ICppStructOps* CppStructOpsBackup;
	void RegisterStructInDeferredList(ICppStructOps* StructOps);



public:
	// UNimScriptStruct(const FObjectInitializer& ObjectInitializer);
	UNimScriptStruct* NewNimScriptStruct; //If ther
	// virtual void InitializeStruct(void* Dest, int32 ArrayDim) const override;
	// virtual void DestroyStruct(void* Dest, int32 ArrayDim) const override;
	FString ueType;
	template<typename T>
	void SetCppStructOpFor(T* FakeObject) {
		
		auto StructOps = new NimStructOps<T>(this);
		RegisterStructInDeferredList(StructOps);
		// CppStructOpsBackup = new NimStructOps<T>(this);
		this->CppStructOps = StructOps;
		this->PrepareCppStructOps();
	}



	// virtual void PrepareCppStructOps() override;
	
};
