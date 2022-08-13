#include "FNimReload.h"

#include "Kismet2/BlueprintEditorUtils.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "Kismet2/KismetReinstanceUtilities.h"
#include "NimForUEBindings/Public/NimScriptStruct.h"
#include "Serialization/ArchiveReplaceObjectRef.h"


/** Helper for finding subobject in an array. Usually there's not that many subobjects on a class to justify a TMap */
FORCEINLINE static UObject* FindDefaultSubobject(TArray<UObject*>& InDefaultSubobjects, FName SubobjectName)
{
	for (UObject* Subobject : InDefaultSubobjects)
	{
		if (Subobject->GetFName() == SubobjectName)
		{
			return Subobject;
		}
	}
	return nullptr;
}

/**
 * Helper class used for re-instancing native and blueprint classes after hot-reload
 */
class FReloadClassReinstancer : public FBlueprintCompileReinstancer
{
	/** Holds a property and its offset in the serialized properties data array */
	struct FCDOProperty
	{
		FCDOProperty()
			: Property(nullptr)
			, SubobjectName(NAME_None)
			, SerializedValueOffset(0)
			, SerializedValueSize(0)
		{}

		FProperty* Property;
		FName SubobjectName;
		int64 SerializedValueOffset;
		int64 SerializedValueSize;
	};

	/** Contains all serialized CDO property data and the map of all serialized properties */
	struct FCDOPropertyData
	{
		TArray<uint8> Bytes;
		TMap<FName, FCDOProperty> Properties;
	};

	/** Hot-reloaded version of the old class */
	UClass* NewClass;

	/** Serialized properties of the original CDO (before hot-reload) */
	FCDOPropertyData OriginalCDOProperties;

	/** Serialized properties of the new CDO (after hot-reload) */
	FCDOPropertyData ReconstructedCDOProperties;

	/** True if the provided native class needs re-instancing */
	bool bNeedsReinstancing;

	/** Necessary for delta serialization */
	UObject* CopyOfPreviousCDO;

	/**
	 * Sets the re-instancer up for new class re-instancing
	 *
	 * @param InNewClass Class that has changed after hot-reload
	 * @param InOldClass Class before it was hot-reloaded
	 */
	void SetupNewClassReinstancing(UClass* InNewClass, UClass* InOldClass);

	/**
	* Sets the re-instancer up for old class re-instancing. Always re-creates the CDO.
	*
	* @param InOldClass Class that has NOT changed after hot-reload
	*/
	void RecreateCDOAndSetupOldClassReinstancing(UClass* InOldClass);

	/**
	* Creates a mem-comparable array of data containing CDO property values.
	*
	* @param InObject CDO
	* @param OutData Data containing all of the CDO property values
	*/
	void SerializeCDOProperties(UObject* InObject, FCDOPropertyData& OutData);

	/**
	 * Re-creates class default object.
	 *
	 * @param InClass Class that has NOT changed after hot-reload.
	 * @param InOuter Outer for the new CDO.
	 * @param InName Name of the new CDO.
	 * @param InFlags Flags of the new CDO.
	 */
	void ReconstructClassDefaultObject(UClass* InClass, UObject* InOuter, FName InName, EObjectFlags InFlags);

	/** Updates property values on instances of the hot-reloaded class */
	void UpdateDefaultProperties();

	/** Returns true if the properties of the CDO have changed during hot-reload */
	FORCEINLINE bool DefaultPropertiesHaveChanged() const
	{
		return OriginalCDOProperties.Bytes.Num() != ReconstructedCDOProperties.Bytes.Num() ||
			FMemory::Memcmp(OriginalCDOProperties.Bytes.GetData(), ReconstructedCDOProperties.Bytes.GetData(), OriginalCDOProperties.Bytes.Num());
	}

public:

	/** Sets the re-instancer up to re-instance native classes */
	FReloadClassReinstancer(UClass* InNewClass, UClass* InOldClass, const TSet<UObject*>& InReinstancingObjects, TMap<UObject*, UObject*>& OutReconstructedCDOsMap, TSet<UBlueprint*>& InCompiledBlueprints);

	/** Destructor */
	virtual ~FReloadClassReinstancer();

	/** If true, the class needs re-instancing */
	FORCEINLINE bool ClassNeedsReinstancing() const
	{
		return bNeedsReinstancing;
	}

	/** Reinstances all objects of the hot-reloaded class and update their properties to match the new CDO */
	void ReinstanceObjectsAndUpdateDefaults();

	/** Creates the reinstancer as a sharable object */
	static TSharedPtr<FReloadClassReinstancer> Create(UClass* InNewClass, UClass* InOldClass, const TSet<UObject*>& InReinstancingObjects, TMap<UObject*, UObject*>& OutReconstructedCDOsMap, TSet<UBlueprint*>& InCompiledBlueprints)
	{
		return MakeShareable(new FReloadClassReinstancer(InNewClass, InOldClass, InReinstancingObjects, OutReconstructedCDOsMap, InCompiledBlueprints));
	}

	// FSerializableObject interface
	virtual void AddReferencedObjects(FReferenceCollector& Collector) override;
	// End of FSerializableObject interface

	virtual bool IsClassObjectReplaced() const override { return true; }

	virtual void BlueprintWasRecompiled(UBlueprint* BP, bool bBytecodeOnly) override;

protected:

	// FBlueprintCompileReinstancer interface
	virtual bool ShouldPreserveRootComponentOfReinstancedActor() const override { return false; }
	// End of FBlueprintCompileReinstancer interface

private:
	/** Reference to reconstructed CDOs map in this hot-reload session. */
	TMap<UObject*, UObject*>& ReconstructedCDOsMap;

	/** Collection of blueprints already recompiled */
	TSet<UBlueprint*>& CompiledBlueprints;
 };

namespace
{
	template<typename T>
	void CollectPackages(TArray<UPackage*>& Packages, const TMap<T*, T*>& Reinstances)
	{
		for (const TPair<T*, T*>& Pair : Reinstances)
		{
			T* Old = Pair.Key;
			T* New = Pair.Value;
			Packages.AddUnique(New ? New->GetPackage() : Old->GetPackage());
		}
	}
}
void FNimReload::ReinstanceClass(UClass* NewClass, UClass* OldClass, const TSet<UObject*>& ReinstancingObjects, TSet<UBlueprint*>& CompiledBlueprints) {
	TSharedPtr<FReloadClassReinstancer> ReinstanceHelper = FReloadClassReinstancer::Create(NewClass, OldClass, ReinstancingObjects, ReconstructedCDOsMap, CompiledBlueprints);
	if (ReinstanceHelper->ClassNeedsReinstancing())
	{
		Ar.Logf(ELogVerbosity::Log, TEXT("Re-instancing %s after reload."), NewClass ? *NewClass->GetName() : *OldClass->GetName());
		ReinstanceHelper->ReinstanceObjectsAndUpdateDefaults();
	}
}

void FNimReload::Reinstance() {
	if (Type != EActiveReloadType::Reinstancing)
	{
		UClass::AssembleReferenceTokenStreams();
	}

	TMap<UClass*, UClass*>& ClassesToReinstance = GetClassesToReinstanceForHotReload();

	// If we have to collect the packages, gather them from the reinstanced objects
	if (bCollectPackages)
	{
		CollectPackages(Packages, ClassesToReinstance);
		CollectPackages(Packages, ReinstancedStructs);
		CollectPackages(Packages, ReinstancedEnums);
	}

	// Remap all native functions (and gather scriptstructs)
	TArray<UScriptStruct*> ScriptStructs;
	for (FRawObjectIterator It; It; ++It)
	{
		if (UFunction* Function = Cast<UFunction>(static_cast<UObject*>(It->Object)))
		{
			if (FNativeFuncPtr NewFunction = FunctionRemap.FindRef(Function->GetNativeFunc()))
			{
				++NumFunctionsRemapped;
				Function->SetNativeFunc(NewFunction);
			}
		} 
		else if (UScriptStruct* ScriptStruct = Cast<UScriptStruct>(static_cast<UObject*>(It->Object)))
		{
			if (!ScriptStruct->HasAnyFlags(RF_ClassDefaultObject) && ScriptStruct->GetCppStructOps() && 
				Packages.ContainsByPredicate([ScriptStruct](UPackage* Package) { return ScriptStruct->IsIn(Package); }))
			{
				ScriptStructs.Add(ScriptStruct);
			}
		}
	}

	// now let's set up the script structs...this relies on super behavior, so null them all, then set them all up. Internally this sets them up hierarchically.
	for (UScriptStruct* Script : ScriptStructs)
	{
		//NimForUE Fix:
		if(UNimScriptStruct* NimScriptStruct = Cast<UNimScriptStruct>(Script)) continue; //Skip nim structs
		Script->ClearCppStructOps();
	}
	for (UScriptStruct* Script : ScriptStructs)
	{
		if(UNimScriptStruct* NimScriptStruct = Cast<UNimScriptStruct>(Script)) continue; //Skip nim structs
		Script->PrepareCppStructOps();
		check(Script->GetCppStructOps());
	}
	NumScriptStructsRemapped = ScriptStructs.Num();

	// Collect all the classes being reinstanced
	TSet<UObject*> ReinstancingObjects;
	ReinstancingObjects.Reserve(ClassesToReinstance.Num() + ReinstancedStructs.Num() + ReinstancedEnums.Num());
	for (const TPair<UClass*, UClass*>& Pair : ClassesToReinstance)
	{
		ReinstancingObjects.Add(Pair.Key);
	}

	// Collect all of the blueprint nodes that are getting updated due to enum/struct changes
	TMap<UBlueprint*, FBlueprintUpdateInfo> ModifiedBlueprints;
	FBlueprintEditorUtils::FOnNodeFoundOrUpdated OnNodeFoundOrUpdated = [&ModifiedBlueprints](UBlueprint* Blueprint, UK2Node* Node)
	{
		// Blueprint can be nullptr
		FBlueprintUpdateInfo& BlueprintUpdateInfo = ModifiedBlueprints.FindOrAdd(Blueprint);
		BlueprintUpdateInfo.Nodes.Add(Node);
	};

	// Update all the structures.  We add the unchanging structs to the list to make sure the defaults are updated
	TMap<UScriptStruct*, UScriptStruct*> ChangedStructs;
	for (const TPair<UScriptStruct*, UScriptStruct*>& Pair : ReinstancedStructs)
	{
		ReinstancingObjects.Add(Pair.Key);
		if (Pair.Value)
		{
			Pair.Key->StructFlags = EStructFlags(Pair.Key->StructFlags | STRUCT_NewerVersionExists);
			ChangedStructs.Emplace(Pair.Key, Pair.Value);
		}
		else
		{
			ChangedStructs.Emplace(Pair.Key, Pair.Key);
		}
	}
	FBlueprintEditorUtils::UpdateScriptStructsInNodes(ChangedStructs, OnNodeFoundOrUpdated);

	// Update all the enumeration nodes
	TMap<UEnum*, UEnum*> ChangedEnums;
	for (const TPair<UEnum*, UEnum*>& Pair : ReinstancedEnums)
	{
		ReinstancingObjects.Add(Pair.Key);
		if (Pair.Value)
		{
			Pair.Key->SetEnumFlags(EEnumFlags::NewerVersionExists);
			ChangedEnums.Emplace(Pair.Key, Pair.Value);
		}
	}
	FBlueprintEditorUtils::UpdateEnumsInNodes(ChangedEnums, OnNodeFoundOrUpdated);

	// Update all the nodes before we could possibly recompile
	for (TPair<UBlueprint*, FBlueprintUpdateInfo>& KVP : ModifiedBlueprints)
	{
		UBlueprint* Blueprint = KVP.Key;
		FBlueprintUpdateInfo& Info = KVP.Value;

		for (UK2Node* Node : Info.Nodes)
		{
			FBlueprintEditorUtils::RecombineNestedSubPins(Node);
		}

		// We must reconstruct the node first other wise some pins might not be 
		// in a good state for the recompile
		for (UK2Node* Node : Info.Nodes)
		{
			Node->ReconstructNode();
		}
	}

	TSet<UBlueprint*> CompiledBlueprints;
	for (const TPair<UClass*, UClass*>& Pair : ClassesToReinstance)
	{
		ReinstanceClass(Pair.Value, Pair.Key, ReinstancingObjects, CompiledBlueprints);
	}

	// Recompile blueprints if they haven't already been recompiled)
	for (TPair<UBlueprint*, FBlueprintUpdateInfo>& KVP : ModifiedBlueprints)
	{
		UBlueprint* Blueprint = KVP.Key;
		FBlueprintUpdateInfo& Info = KVP.Value;

		if (Blueprint && !CompiledBlueprints.Contains(Blueprint))
		{
			EBlueprintCompileOptions Options = EBlueprintCompileOptions::SkipGarbageCollection;
			FKismetEditorUtilities::CompileBlueprint(Blueprint, Options);
		}
	}

	ReinstancedClasses = MoveTemp(ClassesToReinstance);

	FCoreUObjectDelegates::ReloadReinstancingCompleteDelegate.Broadcast();
}



FReloadClassReinstancer::FReloadClassReinstancer(UClass* InNewClass, UClass* InOldClass, const TSet<UObject*>& InReinstancingObjects, TMap<UObject*, UObject*>& OutReconstructedCDOsMap, TSet<UBlueprint*>& InCompiledBlueprints)
	: NewClass(nullptr)
	, bNeedsReinstancing(false)
	, CopyOfPreviousCDO(nullptr)
	, ReconstructedCDOsMap(OutReconstructedCDOsMap)
	, CompiledBlueprints(InCompiledBlueprints)
{
	ensure(InOldClass);
	ensure(!HotReloadedOldClass && !HotReloadedNewClass);
	HotReloadedOldClass = InOldClass;
	HotReloadedNewClass = InNewClass ? InNewClass : InOldClass;

	for (UObject* Object : InReinstancingObjects)
	{
		ObjectsThatShouldUseOldStuff.Add(Object);
	}

	// If InNewClass is NULL, then the old class has not changed after hot-reload.
	// However, we still need to check for changes to its constructor code (CDO values).
	if (InNewClass)
	{
		SetupNewClassReinstancing(InNewClass, InOldClass);

		TMap<UObject*, UObject*> ClassRedirects;
		ClassRedirects.Add(InOldClass, InNewClass);

		for (TObjectIterator<UBlueprint> BlueprintIt; BlueprintIt; ++BlueprintIt)
		{
			constexpr EArchiveReplaceObjectFlags ReplaceObjectArchFlags = (EArchiveReplaceObjectFlags::IgnoreOuterRef | EArchiveReplaceObjectFlags::IgnoreArchetypeRef);
			FArchiveReplaceObjectRef<UObject> ReplaceObjectArch(*BlueprintIt, ClassRedirects, ReplaceObjectArchFlags);
		}
	}
	else
	{
		RecreateCDOAndSetupOldClassReinstancing(InOldClass);
	}
}

FReloadClassReinstancer::~FReloadClassReinstancer()
{
	// Make sure the base class does not remove the DuplicatedClass from root, we not always want it.
	// For example when we're just reconstructing CDOs. Other cases are handled by HotReloadClassReinstancer.
	DuplicatedClass = nullptr;

	ensure(HotReloadedOldClass);
	HotReloadedOldClass = nullptr;
	HotReloadedNewClass = nullptr;
}


void FReloadClassReinstancer::SetupNewClassReinstancing(UClass* InNewClass, UClass* InOldClass)
{
	// Set base class members to valid values
	ClassToReinstance = InNewClass;
	DuplicatedClass = InOldClass;
	OriginalCDO = InOldClass->GetDefaultObject();
	bHasReinstanced = false;
	bNeedsReinstancing = true;
	NewClass = InNewClass;

	// Collect the original CDO property values
	SerializeCDOProperties(InOldClass->GetDefaultObject(), OriginalCDOProperties);
	// Collect the property values of the new CDO
	SerializeCDOProperties(InNewClass->GetDefaultObject(), ReconstructedCDOProperties);

	SaveClassFieldMapping(InOldClass);

	ObjectsThatShouldUseOldStuff.Add(InOldClass); //CDO of REINST_ class can be used as archetype

	TArray<UClass*> ChildrenOfClass;
	GetDerivedClasses(InOldClass, ChildrenOfClass);
	for (auto ClassIt = ChildrenOfClass.CreateConstIterator(); ClassIt; ++ClassIt)
	{
		UClass* ChildClass = *ClassIt;
		UBlueprint* ChildBP = Cast<UBlueprint>(ChildClass->ClassGeneratedBy);
		if (ChildBP && !ChildBP->HasAnyFlags(RF_BeingRegenerated))
		{
			// If this is a direct child, change the parent and relink so the property chain is valid for reinstancing
			if (!ChildBP->HasAnyFlags(RF_NeedLoad))
			{
				if (ChildClass->GetSuperClass() == InOldClass)
				{
					ReparentChild(ChildBP);
				}

				Children.AddUnique(ChildBP);
				if (ChildBP->ParentClass == InOldClass)
				{
					ChildBP->ParentClass = NewClass;
				}
			}
			else
			{
				// If this is a child that caused the load of their parent, relink to the REINST class so that we can still serialize in the CDO, but do not add to later processing
				ReparentChild(ChildClass);
			}
		}
	}

	// Finally, remove the old class from Root so that it can get GC'd and mark it as CLASS_NewerVersionExists
	InOldClass->RemoveFromRoot();
	InOldClass->ClassFlags |= CLASS_NewerVersionExists;
}

void FReloadClassReinstancer::SerializeCDOProperties(UObject* InObject, FReloadClassReinstancer::FCDOPropertyData& OutData)
{
	// Creates a mem-comparable CDO data
	class FCDOWriter : public FMemoryWriter
	{
		/** Objects already visited by this archive */
		TSet<UObject*>& VisitedObjects;
		/** Output property data */
		FCDOPropertyData& PropertyData;
		/** Current subobject being serialized */
		FName SubobjectName;

	public:
		/** Serializes all script properties of the provided DefaultObject */
		FCDOWriter(FCDOPropertyData& InOutData, TSet<UObject*>& InVisitedObjects, FName InSubobjectName)
			: FMemoryWriter(InOutData.Bytes, /* bIsPersistent = */ false, /* bSetOffset = */ true)
			, VisitedObjects(InVisitedObjects)
			, PropertyData(InOutData)
			, SubobjectName(InSubobjectName)
		{
			// Disable delta serialization, we want to serialize everything
			ArNoDelta = true;
		}
		virtual void Serialize(void* Data, int64 Num) override
		{
			// Collect serialized properties so we can later update their values on instances if they change
			FProperty* SerializedProperty = GetSerializedProperty();
			if (SerializedProperty != nullptr)
			{
				FCDOProperty& PropertyInfo = PropertyData.Properties.FindOrAdd(SerializedProperty->GetFName());
				if (PropertyInfo.Property == nullptr)
				{
					PropertyInfo.Property = SerializedProperty;
					PropertyInfo.SubobjectName = SubobjectName;
					PropertyInfo.SerializedValueOffset = Tell();
					PropertyInfo.SerializedValueSize = Num;
				}
				else
				{
					PropertyInfo.SerializedValueSize += Num;
				}
			}
			FMemoryWriter::Serialize(Data, Num);
		}
		/** Serializes an object. Only name and class for normal references, deep serialization for DSOs */
		virtual FArchive& operator<<(class UObject*& InObj) override
		{
			FArchive& Ar = *this;
			if (InObj)
			{
				FName ClassName = InObj->GetClass()->GetFName();
				FName ObjectName = InObj->GetFName();
				Ar << ClassName;
				Ar << ObjectName;
				if (!VisitedObjects.Contains(InObj))
				{
					VisitedObjects.Add(InObj);
					if (Ar.GetSerializedProperty() && Ar.GetSerializedProperty()->ContainsInstancedObjectProperty())
					{
						// Serialize all DSO properties too
						FCDOWriter DefaultSubobjectWriter(PropertyData, VisitedObjects, InObj->GetFName());
						InObj->SerializeScriptProperties(DefaultSubobjectWriter);
						Seek(PropertyData.Bytes.Num());
					}
				}
			}
			else
			{
				FName UnusedName = NAME_None;
				Ar << UnusedName;
				Ar << UnusedName;
			}

			return *this;
		}
		virtual FArchive& operator<<(FObjectPtr& InObj) override
		{
			// Invoke the method above
			return FArchiveUObject::SerializeObjectPtr(*this, InObj);
		}
		/** Serializes an FName as its index and number */
		virtual FArchive& operator<<(FName& InName) override
		{
			FArchive& Ar = *this;
			FNameEntryId ComparisonIndex = InName.GetComparisonIndex();
			FNameEntryId DisplayIndex = InName.GetDisplayIndex();
			int32 Number = InName.GetNumber();
			Ar << ComparisonIndex;
			Ar << DisplayIndex;
			Ar << Number;
			return Ar;
		}
		virtual FArchive& operator<<(FLazyObjectPtr& LazyObjectPtr) override
		{
			FArchive& Ar = *this;
			FUniqueObjectGuid UniqueID = LazyObjectPtr.GetUniqueID();
			Ar << UniqueID;
			return *this;
		}
		virtual FArchive& operator<<(FSoftObjectPtr& Value) override
		{
			FArchive& Ar = *this;
			FSoftObjectPath UniqueID = Value.GetUniqueID();
			Ar << UniqueID;
			return Ar;
		}
		virtual FArchive& operator<<(FSoftObjectPath& Value) override
		{
			FArchive& Ar = *this;

			FString Path = Value.ToString();

			Ar << Path;

			if (IsLoading())
			{
				Value.SetPath(MoveTemp(Path));
			}

			return Ar;
		}
		FArchive& operator<<(FWeakObjectPtr& WeakObjectPtr) override
		{
			return FArchiveUObject::SerializeWeakObjectPtr(*this, WeakObjectPtr);
		}
		/** Archive name, for debugging */
		virtual FString GetArchiveName() const override { return TEXT("FCDOWriter"); }
	};
	TSet<UObject*> VisitedObjects;
	VisitedObjects.Add(InObject);
	FCDOWriter Ar(OutData, VisitedObjects, NAME_None);
	//Test if the class exists here? For now just log it so we know on the next crash
	checkf(InObject->GetClass(), TEXT("Class for %s is null"), *InObject->GetName());
	//NIM FIX. Is crashing here. 
	// InObject->SerializeScriptProperties(Ar); 
}

void FReloadClassReinstancer::ReconstructClassDefaultObject(UClass* InClass, UObject* InOuter, FName InName, EObjectFlags InFlags)
{
	// Get the parent CDO
	UClass* ParentClass = InClass->GetSuperClass();
	UObject* ParentDefaultObject = NULL;
	if (ParentClass != NULL)
	{
		ParentDefaultObject = ParentClass->GetDefaultObject(); // Force the default object to be constructed if it isn't already
	}

	// Re-create
	InClass->ClassDefaultObject = StaticAllocateObject(InClass, InOuter, InName, InFlags, EInternalObjectFlags::None, false);
	check(InClass->ClassDefaultObject);
	(*InClass->ClassConstructor)(FObjectInitializer(InClass->ClassDefaultObject, ParentDefaultObject, EObjectInitializerOptions::None));
}

void FReloadClassReinstancer::RecreateCDOAndSetupOldClassReinstancing(UClass* InOldClass)
{
	// Set base class members to valid values
	ClassToReinstance = InOldClass;
	DuplicatedClass = InOldClass;
	OriginalCDO = InOldClass->GetDefaultObject();
	bHasReinstanced = false;
	bNeedsReinstancing = false;
	NewClass = InOldClass; // The class doesn't change in this case

	// Collect the original property values
	SerializeCDOProperties(InOldClass->GetDefaultObject(), OriginalCDOProperties);

	// Remember all the basic info about the object before we rename it
	EObjectFlags CDOFlags = OriginalCDO->GetFlags();
	UObject* CDOOuter = OriginalCDO->GetOuter();
	FName CDOName = OriginalCDO->GetFName();

	// Rename original CDO, so we can store this one as OverridenArchetypeForCDO
	// and create new one with the same name and outer.
	OriginalCDO->Rename(
		*MakeUniqueObjectName(
			GetTransientPackage(),
			OriginalCDO->GetClass(),
			*FString::Printf(TEXT("BPGC_ARCH_FOR_CDO_%s"), *InOldClass->GetName())
		).ToString(),
		GetTransientPackage(),
		REN_DoNotDirty | REN_DontCreateRedirectors | REN_NonTransactional | REN_SkipGeneratedClasses | REN_ForceNoResetLoaders);

	// Re-create the CDO, re-running its constructor
	ReconstructClassDefaultObject(InOldClass, CDOOuter, CDOName, CDOFlags);

	ReconstructedCDOsMap.Add(OriginalCDO, InOldClass->GetDefaultObject());

	// Collect the property values after re-constructing the CDO
	SerializeCDOProperties(InOldClass->GetDefaultObject(), ReconstructedCDOProperties);

	// We only want to re-instance the old class if its CDO's values have changed or any of its DSOs' property values have changed
	if (DefaultPropertiesHaveChanged())
	{
		bNeedsReinstancing = true;
		SaveClassFieldMapping(InOldClass);

		TArray<UClass*> ChildrenOfClass;
		GetDerivedClasses(InOldClass, ChildrenOfClass);
		for (auto ClassIt = ChildrenOfClass.CreateConstIterator(); ClassIt; ++ClassIt)
		{
			UClass* ChildClass = *ClassIt;
			UBlueprint* ChildBP = Cast<UBlueprint>(ChildClass->ClassGeneratedBy);
			if (ChildBP && !ChildBP->HasAnyFlags(RF_BeingRegenerated))
			{
				if (!ChildBP->HasAnyFlags(RF_NeedLoad))
				{
					Children.AddUnique(ChildBP);
					UBlueprintGeneratedClass* BPGC = Cast<UBlueprintGeneratedClass>(ChildBP->GeneratedClass);
					UObject* CurrentCDO = BPGC ? BPGC->GetDefaultObject(false) : nullptr;
					if (CurrentCDO && (OriginalCDO == CurrentCDO->GetArchetype()))
					{
						BPGC->OverridenArchetypeForCDO = OriginalCDO;
					}
				}
			}
		}
	}
}

void FReloadClassReinstancer::ReinstanceObjectsAndUpdateDefaults()
{
	ReinstanceObjects(true);
	UpdateDefaultProperties();
}

void FReloadClassReinstancer::AddReferencedObjects(FReferenceCollector& Collector)
{
	FBlueprintCompileReinstancer::AddReferencedObjects(Collector);
	Collector.AllowEliminatingReferences(false);
	Collector.AddReferencedObject(CopyOfPreviousCDO);
	Collector.AllowEliminatingReferences(true);
}

void FReloadClassReinstancer::BlueprintWasRecompiled(UBlueprint* BP, bool bBytecodeOnly)
{
	CompiledBlueprints.Add(BP);

	FBlueprintCompileReinstancer::BlueprintWasRecompiled(BP, bBytecodeOnly);
}



void FReloadClassReinstancer::UpdateDefaultProperties()
{
	struct FPropertyToUpdate
	{
		FProperty* Property;
		FName SubobjectName;
		uint8* OldSerializedValuePtr;
		uint8* NewValuePtr;
		int64 OldSerializedSize;
	};
	/** Memory writer archive that supports UObject values the same way as FCDOWriter. */
	class FPropertyValueMemoryWriter : public FMemoryWriter
	{
	public:
		FPropertyValueMemoryWriter(TArray<uint8>& OutData)
			: FMemoryWriter(OutData)
		{}
		virtual FArchive& operator<<(class UObject*& InObj) override
		{
			FArchive& Ar = *this;
			if (InObj)
			{
				FName ClassName = InObj->GetClass()->GetFName();
				FName ObjectName = InObj->GetFName();
				Ar << ClassName;
				Ar << ObjectName;
			}
			else
			{
				FName UnusedName = NAME_None;
				Ar << UnusedName;
				Ar << UnusedName;
			}
			return *this;
		}
		virtual FArchive& operator<<(FObjectPtr& InObj) override
		{
			// Invoke the method above
			return FArchiveUObject::SerializeObjectPtr(*this, InObj);
		}
		virtual FArchive& operator<<(FName& InName) override
		{
			FArchive& Ar = *this;
			FNameEntryId ComparisonIndex = InName.GetComparisonIndex();
			FNameEntryId DisplayIndex = InName.GetDisplayIndex();
			int32 Number = InName.GetNumber();
			Ar << ComparisonIndex;
			Ar << DisplayIndex;
			Ar << Number;
			return Ar;
		}
		virtual FArchive& operator<<(FLazyObjectPtr& LazyObjectPtr) override
		{
			FArchive& Ar = *this;
			FUniqueObjectGuid UniqueID = LazyObjectPtr.GetUniqueID();
			Ar << UniqueID;
			return *this;
		}
		virtual FArchive& operator<<(FSoftObjectPtr& Value) override
		{
			FArchive& Ar = *this;
			FSoftObjectPath UniqueID = Value.GetUniqueID();
			Ar << UniqueID;
			return Ar;
		}
		virtual FArchive& operator<<(FSoftObjectPath& Value) override
		{
			FArchive& Ar = *this;

			FString Path = Value.ToString();

			Ar << Path;

			if (IsLoading())
			{
				Value.SetPath(MoveTemp(Path));
			}

			return Ar;
		}
		FArchive& operator<<(FWeakObjectPtr& WeakObjectPtr) override
		{
			return FArchiveUObject::SerializeWeakObjectPtr(*this, WeakObjectPtr);
		}
	};

	// Collect default subobjects to update their properties too
	const int32 DefaultSubobjectArrayCapacity = 16;
	TArray<UObject*> DefaultSubobjectArray;
	DefaultSubobjectArray.Empty(DefaultSubobjectArrayCapacity);
	NewClass->GetDefaultObject()->CollectDefaultSubobjects(DefaultSubobjectArray);

	TArray<FPropertyToUpdate> PropertiesToUpdate;
	// Collect all properties that have actually changed
	for (const TPair<FName, FCDOProperty>& Pair : ReconstructedCDOProperties.Properties)
	{
		FCDOProperty* OldPropertyInfo = OriginalCDOProperties.Properties.Find(Pair.Key);
		if (OldPropertyInfo)
		{
			const FCDOProperty& NewPropertyInfo = Pair.Value;

			uint8* OldSerializedValuePtr = OriginalCDOProperties.Bytes.GetData() + OldPropertyInfo->SerializedValueOffset;
			uint8* NewSerializedValuePtr = ReconstructedCDOProperties.Bytes.GetData() + NewPropertyInfo.SerializedValueOffset;
			if (OldPropertyInfo->SerializedValueSize != NewPropertyInfo.SerializedValueSize ||
				FMemory::Memcmp(OldSerializedValuePtr, NewSerializedValuePtr, OldPropertyInfo->SerializedValueSize) != 0)
			{
				// Property value has changed so add it to the list of properties that need updating on instances
				FPropertyToUpdate PropertyToUpdate;
				PropertyToUpdate.Property = NewPropertyInfo.Property;
				PropertyToUpdate.NewValuePtr = nullptr;
				PropertyToUpdate.SubobjectName = NewPropertyInfo.SubobjectName;

				if (NewPropertyInfo.Property->GetOwner<UObject>() == NewClass)
				{
					PropertyToUpdate.NewValuePtr = PropertyToUpdate.Property->ContainerPtrToValuePtr<uint8>(NewClass->GetDefaultObject());
				}
				else if (NewPropertyInfo.SubobjectName != NAME_None)
				{
					UObject* DefaultSubobjectPtr = FindDefaultSubobject(DefaultSubobjectArray, NewPropertyInfo.SubobjectName);
					if (DefaultSubobjectPtr && NewPropertyInfo.Property->GetOwner<UObject>() == DefaultSubobjectPtr->GetClass())
					{
						PropertyToUpdate.NewValuePtr = PropertyToUpdate.Property->ContainerPtrToValuePtr<uint8>(DefaultSubobjectPtr);
					}
				}
				if (PropertyToUpdate.NewValuePtr)
				{
					PropertyToUpdate.OldSerializedValuePtr = OldSerializedValuePtr;
					PropertyToUpdate.OldSerializedSize = OldPropertyInfo->SerializedValueSize;

					PropertiesToUpdate.Add(PropertyToUpdate);
				}
			}
		}
	}
	if (PropertiesToUpdate.Num())
	{
		TArray<uint8> CurrentValueSerializedData;

		// Update properties on all existing instances of the class
		const UPackage* TransientPackage = GetTransientPackage();
		for (FThreadSafeObjectIterator It(NewClass); It; ++It)
		{
			UObject* ObjectPtr = *It;
			if (!IsValidChecked(ObjectPtr) || ObjectPtr->GetOutermost() == TransientPackage)
			{
				continue;
			}

			DefaultSubobjectArray.Empty(DefaultSubobjectArrayCapacity);
			ObjectPtr->CollectDefaultSubobjects(DefaultSubobjectArray);

			for (auto& PropertyToUpdate : PropertiesToUpdate)
			{
				uint8* InstanceValuePtr = nullptr;
				if (PropertyToUpdate.SubobjectName == NAME_None)
				{
					InstanceValuePtr = PropertyToUpdate.Property->ContainerPtrToValuePtr<uint8>(ObjectPtr);
				}
				else
				{
					UObject* DefaultSubobjectPtr = FindDefaultSubobject(DefaultSubobjectArray, PropertyToUpdate.SubobjectName);
					if (DefaultSubobjectPtr && PropertyToUpdate.Property->GetOwner<UObject>() == DefaultSubobjectPtr->GetClass())
					{
						InstanceValuePtr = PropertyToUpdate.Property->ContainerPtrToValuePtr<uint8>(DefaultSubobjectPtr);
					}
				}

				if (InstanceValuePtr)
				{
					// Serialize current value to a byte array as we don't have the previous CDO to compare against, we only have its serialized property data
					CurrentValueSerializedData.Empty(CurrentValueSerializedData.Num() + CurrentValueSerializedData.GetSlack());
					FPropertyValueMemoryWriter CurrentValueWriter(CurrentValueSerializedData);
					PropertyToUpdate.Property->SerializeItem(FStructuredArchiveFromArchive(CurrentValueWriter).GetSlot(), InstanceValuePtr);

					// Update only when the current value on the instance is identical to the original CDO
					if (CurrentValueSerializedData.Num() == PropertyToUpdate.OldSerializedSize &&
						FMemory::Memcmp(CurrentValueSerializedData.GetData(), PropertyToUpdate.OldSerializedValuePtr, CurrentValueSerializedData.Num()) == 0)
					{
						// Update with the new value
						PropertyToUpdate.Property->CopyCompleteValue(InstanceValuePtr, PropertyToUpdate.NewValuePtr);
					}
				}
			}
		}
	}
}
