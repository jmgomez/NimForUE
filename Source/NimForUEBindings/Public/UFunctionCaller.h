#pragma once

//Not sure if this will only work with prim types
template<typename T>
static void CopyArray(FArrayProperty* ArrayProp, void* SrcMem, void* DstMem) {
	FScriptArrayHelper HelperSrc(ArrayProp, SrcMem);
	FScriptArrayHelper HelperDst(ArrayProp, DstMem);
	HelperDst.AddUninitializedValues(HelperSrc.Num());
	for(int i=0; i<HelperSrc.Num(); i++) {
		T* Value = reinterpret_cast<T*>(HelperSrc.GetRawPtr(i));
		T* Dst = reinterpret_cast<T*>(HelperDst.GetRawPtr(i));
		*Dst = *Value;
	}
}

static void FPropertyGetter(FProperty* Property, void* ReturnResult, void* Container) {
	void* ToReturn = nullptr;
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		ToReturn = StrProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		ToReturn = IntProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Property)) {
		ToReturn = FloatProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FBoolProperty* BoolProperty = CastField<FBoolProperty>(Property)) {
		bool Value = BoolProperty->GetPropertyValue_InContainer(Container);
		bool* ReturnResultBool = (bool*) ReturnResult;
		*ReturnResultBool = Value;
		return;
	}
	
	if(FArrayProperty* ArrayProp = CastField<FArrayProperty>(Property)) {
		ToReturn = ArrayProp->GetPropertyValuePtr_InContainer(Container);
	}

	if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Property)) {
		ToReturn = ObjProp->GetPropertyValuePtr_InContainer(Container);
	}

	if(ToReturn != nullptr)
		FMemory::Memcpy(ReturnResult, ToReturn, Property->GetSize());
		// FMemory::Memmove(ReturnResult, ToReturn, Property->GetSize());
}


class UFunctionCaller {
	uint8* Params;
	UFunction* Function;
	//This gets init in the Function call
	uint8* MemoryFrame;
public:
	static void NimForUELog(FString& Msg) {
		UE_LOG(LogTemp, Log, TEXT("From Nim: %s"), *Msg);
	}
	static void CallUFunctionOn(UObject* Executor, FString& FunctionName, void* InParams) {
		UFunctionCaller(Executor->GetClass(), FunctionName, InParams).Invoke(Executor);
	}
	static void CallUFunctionOn(UClass* Class, FString& FunctionName, void* InParams) {
		UFunctionCaller(Class, FunctionName, InParams).Invoke(Class->GetDefaultObject());
	}
	
	UFunctionCaller(UFunction* InFunction, void* InParams) {
		Function = InFunction;
		Params = (uint8*)InParams;
	}
	UFunctionCaller(UClass* Class, FString &FunctionName, void* InParams) {
		FunctionName.TrimToNullTerminator();
		Function = Class->FindFunctionByName(FName(FunctionName));
		checkf(Function, TEXT("Cant find function %s in class %s"), *FunctionName, *Class->GetName());
		Params = (uint8*)InParams;
	}
	
	void Invoke2(UObject* Executor, void* ReturnResult = nullptr) {
		MemoryFrame = (uint8*)FMemory_Alloca(Function->ParmsSize);
		//Params expect to be in cont memory (struct1, struct2,...)
		FMemory::Memcpy(MemoryFrame, &Params, Function->ParmsSize);
		//MemoryFrame = ..Params + Return
		//Initialize any local struct properties with the params
		for (TFieldIterator<FProperty> It(Function); It; ++It){
			FProperty* Prop = *It;
			if(Prop == nullptr) {
				UE_LOG(LogTemp, Error, TEXT("The property is null. This is probably due to the params sent from nim"));
				continue;
			}
			Prop->InitializeValue_InContainer(MemoryFrame); 
			if(Prop->HasAnyPropertyFlags(CPF_Parm) && !Prop->HasAnyPropertyFlags(CPF_ReturnParm | CPF_OutParm)) {
				if(FStrProperty* StrProperty = CastField<FStrProperty>(Prop)) {
					FString* Value = StrProperty->GetPropertyValuePtr_InContainer(Params);
					StrProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				if(FIntProperty* IntProperty = CastField<FIntProperty>(Prop)) {
					int* Value = IntProperty->GetPropertyValuePtr_InContainer(Params);
					IntProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Prop)) {
					float* Value = FloatProperty->GetPropertyValuePtr_InContainer(Params);
					FloatProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				if(FBoolProperty* BoolProperty = CastField<FBoolProperty>(Prop)) {
					bool Value = BoolProperty->GetPropertyValue_InContainer(Params);
					BoolProperty->SetPropertyValue_InContainer(MemoryFrame, Value);
				}
				
				if(FArrayProperty* ArrayProp = CastField<FArrayProperty>(Prop)) {
					// if(FIntProperty* IntProperty = CastField<FIntProperty>(ArrayProp->Inner)) {
					// 	CopyArray<int>(ArrayProp, Params, MemoryFrame);
					// }
					if(FStrProperty* StrProperty = CastField<FStrProperty>(ArrayProp->Inner)) {
					
						FScriptArrayHelper HelperSrc(ArrayProp, Params);
						FScriptArrayHelper HelperDst(ArrayProp, MemoryFrame);
						HelperDst.AddUninitializedValues(HelperSrc.Num());
						// FScriptArray& SourceArray = *(FScriptArray*)HelperSrc.GetRawPtr(0);
						// FScriptArray& DestinationArray = *(FScriptArray*)HelperDst.GetRawPtr(0);
						// int32 ElementSize = ArrayProp->Inner->ElementSize;
						// TArray<FString>* Src = (TArray<FString>*)(void*)HelperSrc.GetRawPtr(0);
						
						// UE_LOG(LogTemp, Warning, TEXT("Number elements: %d"),HelperSrc.Num());
						for (int32 i = 0; i <HelperSrc.Num(); i++) {
							FString* Value = (FString*)HelperSrc.GetRawPtr(i);
							// UE_LOG(LogTemp, Warning, TEXT("From Nim: %s"), **Value);
							// FString* Dst = (FString*)HelperSrc.GetRawPtr(i);
							// *Dst = *Value;
							uint8* StrMem = (uint8*)FMemory_Alloca(Value->Len());
							FString* StrVal = (FString*) StrMem;
							*StrVal = *Value;
							
							FMemory::Memcpy(HelperDst.GetRawPtr(i), StrMem, ArrayProp->Inner->ElementSize);
						}
						}
						// FMemory::Memcpy(HelperDst.GetRawPtr(0), HelperSrc.GetRawPtr(0), 4 * ArrayProp->Inner->ElementSize);
						// FString* Str = (FString*)HelperSrc.GetRawPtr(0);
						// TArray<FString>* Dst = (TArray<FString>*)(void*)(&DestinationArray);
						// *Dst = *Src;
						// for(FString Str : *Src) {
						// FString* Str = (FString*)HelperSrc.GetRawPtr(0);
						// }
						// for (int32 i = 0; i < HelperSrc.Num(); ++i)
						// {
						// 	void* SourceContainer = (void*)((SIZE_T)SourceArray.GetData() + (i * ElementSize));
						// 	void* DestinyContainer = (void*)((SIZE_T)DestinationArray.GetData() + (i * ElementSize));
						// 	FString* Value = StrProperty->GetPropertyValuePtr_InContainer(SourceContainer);
						// 	UE_LOG(LogTemp, Log, TEXT("From Nim: %s"), **Value);
						// 	// StrProperty->SetPropertyValue_InContainer(DestinyContainer, *Value);
						// }
						// int32 SourceNum = SourceArray.Num();
						// int32 DestNum = DestinationArray.Num();
						//
						// FMemory::Memcpy(DestinationArray.GetData(), SourceArray.GetData(), SourceNum * ElementSize);
					// }
					

					
					continue;
				}

					
					
				if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Prop)) {
					if(Function->NumParms == 1) {
						ObjProp->SetObjectPropertyValue_InContainer(MemoryFrame, (UObject*)Params);
						continue;
					}
					UObject* Value = ObjProp->GetObjectPropertyValue_InContainer(Params);
					ObjProp->SetObjectPropertyValue_InContainer(MemoryFrame, Value);
				}
			}
		}

		Executor->ProcessEvent( Function, MemoryFrame );

		// // destruct properties on the stack, except for out params since we know we didn't use that memory
		for (TFieldIterator<FProperty> It(Function); It; ++It){
			FProperty* Destruct = *It;
			if (!Destruct->HasAnyPropertyFlags(CPF_OutParm | CPF_ReturnParm)){
				 Destruct->DestroyValue_InContainer(MemoryFrame);
					
			}
		}

		for (TFieldIterator<FProperty> It(Function); It; ++It) {
			FProperty* OutProp = *It; //TODO Reuse the return code above
			if (OutProp->HasAnyPropertyFlags(CPF_OutParm) & !OutProp->HasAnyPropertyFlags(CPF_ReturnParm)) {
				if(FStrProperty* StrProperty = CastField<FStrProperty>(OutProp)) {
					FString Value = *StrProperty->GetPropertyValuePtr_InContainer(MemoryFrame);
					StrProperty->SetPropertyValue_InContainer(Params, Value);
				}
				
			}
		}

		FProperty* ReturnProp = Function->GetReturnProperty();
		if(ReturnProp) {
			FPropertyGetter(ReturnProp, ReturnResult, MemoryFrame);
			
		}
	}

	void Invoke(UObject* Executor) {
	
		
		
		Executor->ProcessEvent( Function, Params );
		
		// FProperty* ReturnProp = Function->GetReturnProperty();
		// if(ReturnProp) {
		// 	FPropertyGetter(ReturnProp, ReturnResult, Params);
		// }
	}


};

