// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Async/Async.h"
#include "UObject/Object.h"
#include "ReflectionHelpers.generated.h"


// class UInputAction;
// class UEnhancedInputComponent;
// enum class ETriggerEvent : uint8;
// struct FNimHotReload;
/**
 * 
 */
UCLASS()
class NIMFORUEBINDINGS_API UReflectionHelpers : public UObject {
	GENERATED_BODY()
public:
	static UClass* GetClassByName(FString ClassName);
	UFUNCTION(BlueprintCallable)
	static UScriptStruct* GetScriptStructByName(FString StructName);
	UFUNCTION(BlueprintCallable)
	static UStruct* GetUStructByName(FString StructName);

	template<typename T>
	static T* GetUTypeByName(FString StructName) {
		UObject* ClassPackage = ANY_PACKAGE;
		T* Struct = FindObject<T>(ClassPackage, *StructName);
		return Struct;
	}

	static UObject* NewObjectFromClass(UObject* Owner, UClass* Class, FName Name);
	static UObject* NewObjectFromClass(FStaticConstructObjectParameters Params);

	//Need to do UStruct version or it can also be passed over here somehow? It maybe as easy as just change the type from UClass to UStruct (since UClass derives from UStruct)
	static FProperty* GetFPropetyByName(UStruct* Struct, FString& Name);


	static TArray<FProperty*> GetFPropertiesFrom(UStruct* Struct);

	//FFrameUtils
	template<class TProperty, typename TNativeType>
	static TNativeType& StepCompiledInRef(FFrame* Frame, void*const TemporaryBuffer, TProperty* Ignore) {
		return Frame->StepCompiledInRef<TProperty, TNativeType>(TemporaryBuffer);
	}
	
	template<class T>
	static T* CreateDefaultSubobjectNim(UObject* Outer, FName Name) {
		return Outer->CreateDefaultSubobject<T>(Name, false);
	}
	
	template<typename T>
	static UClass* FromSubclass(TSubclassOf<T> SubclassOf) {
		return SubclassOf;
	}
	template<typename T>
	static TSubclassOf<T> ToSubclass() {
		return T::StaticClass();
	}

	UFUNCTION(BlueprintCallable)
	UClass* TestComp() {
		return FromSubclass(ToSubclass<UObject>());
	}

	static FNativeFuncPtr MakeFNativeFuncPtr(void FnPtr(UObject* Context, FFrame& TheStack, void* Result)) {
		
		return FnPtr;
	}
	static void IncreaseStack(FFrame& Stack);
	template<typename TProperty>
	static void StepCompiledIn(FFrame& Stack, void* Result,   TProperty* FakePropType) {
		Stack.StepCompiledIn<TProperty>(Result);
	}

	static FString GetCppType(FProperty* Property);
	static TArray<UClass*> GetAllClassesFromModule(FString ModuleName);
	
	template<typename T>
	static TArray<T*> GetAllObjectsFromPackage(UPackage* Package) {
			TArray<T*> Objects = {};
			ForEachObjectWithPackage(Package, [&](UObject* Object) {
				if(T* Obj = Cast<T>(Object))
					Objects.Add(Obj);
					return true;
				});
			return Objects;
	}
	//temp fix
	static void AddClassFlag(UClass* Cls, EClassFlags FlagToAdd) {
		Cls->ClassFlags |= FlagToAdd;
	}
	static void AddScriptStructFlag(UScriptStruct* Struct, EStructFlags FlagsToAdd) {
		//Odd issue, it doesnt compile without the static_cast
		Struct->StructFlags = static_cast<EStructFlags>(Struct->StructFlags | FlagsToAdd);
		
	}
	
	//For testing only
	static UWorld* GetCurrentActiveWorld();

	static void NimForUELog(FString Msg);
	static void NimForUEWarn(FString Msg);
	static void NimForUEError(FString Msg);
	
	static TArray<FString> GetEnums(UEnum* Enum);

	static TArray<FString> GetAllModuleDepsForPlugin(FString PluginName);

	static UPackage* CreateNimPackage(FString PackageShortName);

	template<typename T>
	static void ExecuteTaskInTaskGraph(T Param, void (*taskFn)(T)) {
		Async(EAsyncExecution::ThreadPool, [&] {taskFn(Param); });
	}

	static int ExecuteCmd(FString& Cmd, FString& Args, FString& WorkingDir, FString& StdOut, FString& StdError);

	static bool ContainsStrongReference(FProperty* Property);
	
	static void SetClassConstructor(UClass* Class, void (*NimClassConstructor) (FObjectInitializer&));
	static UObject* ConstructFromVTable(UObject* (*ClsVTableHelperCtor)(FVTableHelper& Helper));
	//
	// //Input action
	// UFUNCTION()
	// static void BindAction(UEnhancedInputComponent* InputComponent,UInputAction* Action, ETriggerEvent TriggerEvent, UObject* Object, FName FunctionName);
};

