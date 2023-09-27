// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/UserDefinedStruct.h"
#include "UObject/Object.h"
#include "NimScriptStruct.generated.h"

/** Template to manage dynamic access to C++ struct construction and destruction **/
	template<class CPPSTRUCT>
	struct TNimCppStructOps final : public UScriptStruct::ICppStructOps
	{
		typedef TStructOpsTypeTraits<CPPSTRUCT> TTraits;
		TNimCppStructOps()
			: ICppStructOps(sizeof(CPPSTRUCT), alignof(CPPSTRUCT))
		{
		}

		virtual FCapabilities GetCapabilities() const override
		{
#if  (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 3)
			constexpr FCapabilities Capabilities {
				(TIsPODType<CPPSTRUCT>::Value ? CPF_IsPlainOldData : CPF_None)
				| (TIsTriviallyDestructible<CPPSTRUCT>::Value ? CPF_NoDestructor : CPF_None)
				| (TIsZeroConstructType<CPPSTRUCT>::Value ? CPF_ZeroConstructor : CPF_None)
				| (TModels_V<CGetTypeHashable, CPPSTRUCT> ? CPF_HasGetValueTypeHash : CPF_None),
				TTraits::WithSerializerObjectReferences,
				TTraits::WithNoInitConstructor,
				TTraits::WithZeroConstructor,
				!(TTraits::WithNoDestructor || TIsPODType<CPPSTRUCT>::Value),
				TTraits::WithSerializer,
				TTraits::WithStructuredSerializer,
				TTraits::WithPostSerialize,
				TTraits::WithNetSerializer,
				TTraits::WithNetSharedSerialization,
				TTraits::WithNetDeltaSerializer,
				TTraits::WithPostScriptConstruct,
				TIsPODType<CPPSTRUCT>::Value,
				TIsUECoreType<CPPSTRUCT>::Value,
				TIsUECoreVariant<CPPSTRUCT>::Value,
				TTraits::WithCopy,
				TTraits::WithIdentical || TTraits::WithIdenticalViaEquality,
				TTraits::WithExportTextItem,
				TTraits::WithImportTextItem,
				TTraits::WithAddStructReferencedObjects,
				TTraits::WithSerializeFromMismatchedTag,
				TTraits::WithStructuredSerializeFromMismatchedTag,
				TModels_V<CGetTypeHashable, CPPSTRUCT>,
				TIsAbstract<CPPSTRUCT>::Value,
				TTraits::WithFindInnerPropertyInstance,
#if WITH_EDITOR
				TTraits::WithCanEditChange,
#endif
			};
			return Capabilities;
#else
		constexpr FCapabilities Capabilities {
				(TIsPODType<CPPSTRUCT>::Value ? CPF_IsPlainOldData : CPF_None)
				| CPF_NoDestructor
				| (TIsZeroConstructType<CPPSTRUCT>::Value ? CPF_ZeroConstructor : CPF_None)
				| (TModels<CGetTypeHashable, CPPSTRUCT>::Value ? CPF_HasGetValueTypeHash : CPF_None),
				TTraits::WithNoInitConstructor,
				TTraits::WithZeroConstructor,
				TTraits::WithNoDestructor,
				TTraits::WithSerializer,
				TTraits::WithStructuredSerializer,
				TTraits::WithPostSerialize,
				TTraits::WithNetSerializer,
				TTraits::WithNetSharedSerialization,
				TTraits::WithNetDeltaSerializer,
				TTraits::WithPostScriptConstruct,
				TIsPODType<CPPSTRUCT>::Value,
				TIsUECoreType<CPPSTRUCT>::Value,
				TIsUECoreVariant<CPPSTRUCT>::Value,
				TTraits::WithCopy,
				TTraits::WithIdentical || TTraits::WithIdenticalViaEquality,
				TTraits::WithExportTextItem,
				TTraits::WithImportTextItem,
				TTraits::WithAddStructReferencedObjects,
				TTraits::WithSerializeFromMismatchedTag,
				TTraits::WithStructuredSerializeFromMismatchedTag,
				TModels<CGetTypeHashable, CPPSTRUCT>::Value,
				TIsAbstract<CPPSTRUCT>::Value,
		#if WITH_EDITOR
						TTraits::WithCanEditChange,
		#endif
					};
					
					return Capabilities;
#endif
		}

		virtual void Construct(void* Dest) override
		{
			check(!TTraits::WithZeroConstructor); // don't call this if we have indicated it is not necessary
			// that could have been an if statement, but we might as well force optimization above the virtual call
			// could also not attempt to call the constructor for types where this is not possible, but I didn't do that here
#if CHECK_PUREVIRTUALS
			if constexpr (!TStructOpsTypeTraits<CPPSTRUCT>::WithPureVirtual)
#endif
			{
				if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithNoInitConstructor)
				{
					new (Dest) CPPSTRUCT(ForceInit);
				}
				else
				{
					new (Dest) CPPSTRUCT();
				}
			}
		}
		virtual void ConstructForTests(void* Dest) override
		{
			check(!TTraits::WithZeroConstructor); // don't call this if we have indicated it is not necessary
			// that could have been an if statement, but we might as well force optimization above the virtual call
			// could also not attempt to call the constructor for types where this is not possible, but I didn't do that here
#if CHECK_PUREVIRTUALS
			if constexpr (!TStructOpsTypeTraits<CPPSTRUCT>::WithPureVirtual)
#endif
			{
				if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithNoInitConstructor)
				{
					new (Dest) CPPSTRUCT(ForceInit);
				}
				else
				{
					new (Dest) CPPSTRUCT;
				}
			}
		}
		virtual void Destruct(void *Dest) override
		{
			//NimStructs doesnt have destructor. TODO Consider hooking up ORC in the future here.
		}
		virtual bool Serialize(FArchive& Ar, void *Data) override
		{
			check(TTraits::WithSerializer); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithSerializer)
			{
				return ((CPPSTRUCT*)Data)->Serialize(Ar);
			}
			else
			{
				return false;
			}
		}
		virtual bool Serialize(FStructuredArchive::FSlot Slot, void *Data) override
		{
			check(TTraits::WithStructuredSerializer); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithStructuredSerializer)
			{
				return ((CPPSTRUCT*)Data)->Serialize(Slot);
			}
			else
			{
				return false;
			}
		}
		virtual void PostSerialize(const FArchive& Ar, void *Data) override
		{
			check(TTraits::WithPostSerialize); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithPostSerialize)
			{
				((CPPSTRUCT*)Data)->PostSerialize(Ar);
			}
		}
		virtual bool NetSerialize(FArchive& Ar, class UPackageMap* Map, bool& bOutSuccess, void *Data) override
		{
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithNetSerializer)
			{
				return ((CPPSTRUCT*)Data)->NetSerialize(Ar, Map, bOutSuccess);
			}
			else
			{
				return false;
			}
		}
		virtual bool NetDeltaSerialize(FNetDeltaSerializeInfo & DeltaParms, void *Data) override
		{
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithNetDeltaSerializer)
			{
				return ((CPPSTRUCT*)Data)->NetDeltaSerialize(DeltaParms);
			}
			else
			{
				return false;
			}
		}
		virtual void PostScriptConstruct(void *Data) override
		{
			check(TTraits::WithPostScriptConstruct); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithPostScriptConstruct)
			{
				((CPPSTRUCT*)Data)->PostScriptConstruct();
			}
		}
		virtual void GetPreloadDependencies(void* Data, TArray<UObject*>& OutDeps) override
		{
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithGetPreloadDependencies)
			{
				((CPPSTRUCT*)Data)->GetPreloadDependencies(OutDeps);
			}
		}
		virtual bool Copy(void* Dest, void const* Src, int32 ArrayDim) override
		{
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithCopy)
			{
				static_assert((!TIsPODType<CPPSTRUCT>::Value), "You probably don't want custom copy for a POD type.");

				CPPSTRUCT* TypedDest = (CPPSTRUCT*)Dest;
				const CPPSTRUCT* TypedSrc  = (const CPPSTRUCT*)Src;

				for (; ArrayDim; --ArrayDim)
				{
					*TypedDest++ = *TypedSrc++;
				}
				return true;
			}
			else
			{
				return false;
			}
		}
		virtual bool Identical(const void* A, const void* B, uint32 PortFlags, bool& bOutResult) override
		{
			check((TTraits::WithIdentical || TTraits::WithIdenticalViaEquality)); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithIdentical)
			{
				static_assert(!TStructOpsTypeTraits<CPPSTRUCT>::WithIdenticalViaEquality, "Should not have both WithIdenticalViaEquality and WithIdentical.");

				bOutResult = ((const CPPSTRUCT*)A)->Identical((const CPPSTRUCT*)B, PortFlags);
				return true;
			}
			else if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithIdenticalViaEquality)
			{
				bOutResult = (*(const CPPSTRUCT*)A == *(const CPPSTRUCT*)B);
				return true;
			}
			else
			{
				bOutResult = false;
				return false;
			}
		}
		virtual bool ExportTextItem(FString& ValueStr, const void* PropertyValue, const void* DefaultValue, class UObject* Parent, int32 PortFlags, class UObject* ExportRootScope) override
		{
			check(TTraits::WithExportTextItem); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithExportTextItem)
			{
				if (DefaultValue)
				{
					return ((const CPPSTRUCT*)PropertyValue)->ExportTextItem(ValueStr, *(const CPPSTRUCT*)DefaultValue, Parent, PortFlags, ExportRootScope);
				}
				else
				{
					TTypeCompatibleBytes<CPPSTRUCT> TmpDefaultValue;
					FMemory::Memzero(TmpDefaultValue.GetTypedPtr(), sizeof(CPPSTRUCT));
					if (!HasZeroConstructor())
					{
						Construct(TmpDefaultValue.GetTypedPtr());
					}

					const bool bResult = ((const CPPSTRUCT*)PropertyValue)->ExportTextItem(ValueStr, *(const CPPSTRUCT*)TmpDefaultValue.GetTypedPtr(), Parent, PortFlags, ExportRootScope);

					if (HasDestructor())
					{
						Destruct(TmpDefaultValue.GetTypedPtr());
					}

					return bResult;
				}
			}
			else
			{
				return false;
			}
		}
		virtual bool ImportTextItem(const TCHAR*& Buffer, void* Data, int32 PortFlags, class UObject* OwnerObject, FOutputDevice* ErrorText) override
		{
			check(TTraits::WithImportTextItem); // don't call this if we have indicated it is not necessary
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithImportTextItem)
			{
				return ((CPPSTRUCT*)Data)->ImportTextItem(Buffer, PortFlags, OwnerObject, ErrorText);
			}
			else
			{
				return false;
			}
		}
		virtual TPointerToAddStructReferencedObjects AddStructReferencedObjects() override
		{
			check(TTraits::WithAddStructReferencedObjects); // don't call this if we have indicated it is not necessary
			return &AddStructReferencedObjectsOrNot<CPPSTRUCT>;
		}
		virtual bool SerializeFromMismatchedTag(struct FPropertyTag const& Tag, FArchive& Ar, void *Data) override
		{
			check(TTraits::WithSerializeFromMismatchedTag); // don't call this if we have indicated it is not allowed
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithSerializeFromMismatchedTag)
			{
				if constexpr (TIsUECoreType<CPPSTRUCT>::Value)
				{
					// Custom version of SerializeFromMismatchedTag for core types, which don't have access to FPropertyTag.
					return ((CPPSTRUCT*)Data)->SerializeFromMismatchedTag(Tag.StructName, Ar);
				}
				else
				{
					return ((CPPSTRUCT*)Data)->SerializeFromMismatchedTag(Tag, Ar);
				}
			}
			else
			{
				return false;
			}
		}
		virtual bool StructuredSerializeFromMismatchedTag(struct FPropertyTag const& Tag, FStructuredArchive::FSlot Slot, void *Data) override
		{
			check(TTraits::WithStructuredSerializeFromMismatchedTag); // don't call this if we have indicated it is not allowed
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithStructuredSerializeFromMismatchedTag)
			{
				if constexpr (TIsUECoreType<CPPSTRUCT>::Value)
				{
					// Custom version of SerializeFromMismatchedTag for core types, which don't understand FPropertyTag.
					return ((CPPSTRUCT*)Data)->SerializeFromMismatchedTag(Tag.StructName, Slot);
				}
				else
				{
					return ((CPPSTRUCT*)Data)->SerializeFromMismatchedTag(Tag, Slot);
				}
			}
			else
			{
				return false;
			}
		}

		static_assert(!(TTraits::WithSerializeFromMismatchedTag && TTraits::WithStructuredSerializeFromMismatchedTag), "Structs cannot have both WithSerializeFromMismatchedTag and WithStructuredSerializeFromMismatchedTag set");

		uint32 GetStructTypeHash(const void* Src) override
		{
			ensure(HasGetTypeHash());

			if constexpr (TModels<CGetTypeHashable, CPPSTRUCT>::Value)
			{
				return GetTypeHash(*(const CPPSTRUCT*)Src);
			}
			else
			{
				return 0;
			}
		}

#if WITH_EDITOR

		virtual bool CanEditChange(const FEditPropertyChain& PropertyChain, const void* Data) const override
		{
			if constexpr (TStructOpsTypeTraits<CPPSTRUCT>::WithCanEditChange)
			{
				return ((const CPPSTRUCT*)Data)->CanEditChange(PropertyChain);
			}
			else
			{
				return false;
			}
		}
#endif // WITH_EDITOR


//5.3 up
		virtual bool FindInnerPropertyInstance(FName PropertyName, const void* Data, const FProperty*& OutProp, const void*& OutData) const {
			return false;
		}

		
	};



UCLASS()
class NIMFORUEBINDINGS_API UNimScriptStruct : public UScriptStruct {
	GENERATED_BODY()

	ICppStructOps* OriginalStructOps;//To be used as fallback for prepareStruct
public:
	// explicit UNimScriptStruct(UScriptStruct* InSuperStruct, SIZE_T ParamsSize = 0, SIZE_T Alignment = 0);
	//UNimScriptStruct(UStrøuct* InSuperStruct, SIZE_T ParamsSize = 0, SIZE_T Alignment = 0);
    UNimScriptStruct(const FObjectInitializer& ObjectInitializer, UScriptStruct* InSuperStruct, ICppStructOps* InCppStructOps = nullptr, EStructFlags InStructFlags = STRUCT_NoFlags, SIZE_T ExplicitSize = 0, SIZE_T ExplicitAlignment = 0);
	UNimScriptStruct(){};
	template<typename T>
	void SetCppStructOpFor(T* FakeObject) {
		// Now is final. If using it right away doesnt work or we find a missmatch (which we will probably do) we could reimplement it
		//Notice, since UE 5.1, we could even pass what we need from Nim directly alongside T or maybe even without it
		this->ClearCppStructOps();
		this->CppStructOps = new TNimCppStructOps<T>();
		this->OriginalStructOps = new TNimCppStructOps<T>();
		this->PrepareCppStructOps();
	}
	//We need to override this because the FReload reinstancer will
	//check for the ops of the previus struct and it wont be here because
	virtual void PrepareCppStructOps() override;

	
};
