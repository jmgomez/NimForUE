
//
#include "TestUtils.h"
#include "UFunctionCaller.h"
#include "Misc/AutomationTest.h"
#include "NimForUETest/Public/TestObjects/FunctionTestObject.h"

// IMPLEMENT_SIMPLE_AUTOMATION_TEST(FNimForUETestSpec, "NimForUETest.NaiveTest", TestFlags)
// bool FNimForUETestSpec::RunTest(const FString& Parameters) {
// 	
// 	TestTrue("SPECS ARE EQUAL", true);
//     UE_LOG(LogTemp, Warning, TEXT("Size of int %i"), sizeof(int));
//     UE_LOG(LogTemp, Warning, TEXT("Size of char %i"), sizeof(char));
//     UE_LOG(LogTemp, Warning, TEXT("Size of FString %i"), sizeof(FString));
//     UE_LOG(LogTemp, Warning, TEXT("Size of Pointer %i"), sizeof(UObject*));
//     UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char> %i"), sizeof(TTuple<int, char>));
//     UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char, UObject*> %i"), sizeof(TTuple<int, char, UObject*>));
//     UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char, UObject*, FString> %i"), sizeof(TTuple<int, char, UObject*, FString>));
//
// 	return true;
// };
//
// //FIND SHORTER TESTS DECLARATION

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToHandleFStringAsArgumentAndOutPut, "NimForUETest.ShouldBeAbleToHandleFStringAsArgumentAndOutPut", TestFlags)
bool ShouldBeAbleToHandleFStringAsArgumentAndOutPut::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	FString Param = "Test";
	FString ExpectedResult = TestObject->GetStringTwice(Param);
	UFunction* Function = TestObject->FindFunction(FName("GetStringTwice"));
	UFunctionCaller FunctionCaller (Function, (void*)&Param);
	
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);
	
	// FString Result = FunctionCaller.GetReturnValueAsStr();
	UE_LOG(LogTemp, Warning, TEXT("FROM TEST The return value is %s"), *Result);
	bool Test = Result.Equals(ExpectedResult);
	TestTrue("It's the same", Result.Equals(ExpectedResult));
	return true;
};


// //
IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput, "NimForUETest.ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput", TestFlags)
bool ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	TTuple<FString, FString> Params = MakeTuple("Test1", "Test2");

	FString ExpectedResult = TestObject->AddStrings(Params.Get<0>(), Params.Get<1>());
	

	UFunction* Function = TestObject->FindFunction(FName("AddStrings"));
	UFunctionCaller FunctionCaller (Function, (void*)&Params);
	
	// return true;
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);

	TestTrue("It's the same", Result.Equals(ExpectedResult));
	return true;
};
IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToHandleThreeFStringsParameterAndReturn, "NimForUETest.ShouldBeAbleToHandleThreeFStringsParameterAndReturn", TestFlags)
bool ShouldBeAbleToHandleThreeFStringsParameterAndReturn::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	TTuple<FString, FString, FString> Params = MakeTuple("Test1", "Test2", "Test3");

	FString ExpectedResult = TestObject->AddThreeStrings(Params.Get<0>(), Params.Get<1>(), Params.Get<2>());
	

	UFunction* Function = TestObject->FindFunction(FName("AddThreeStrings"));
	UFunctionCaller FunctionCaller (Function, (void*)&Params);
	
	// return true;
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);

	TestTrue("It's the same", Result.Equals(ExpectedResult));
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleIntAsInput, "NimForUETest.ShouldHandleIntAsInput", TestFlags)
bool ShouldHandleIntAsInput::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	int Param = 5;
	FString ExpectedResult = TestObject->ConvertIntToString(Param);
	
	UFunction* Function = TestObject->FindFunction(FName("ConvertIntToString"));
	UFunctionCaller FunctionCaller (Function, (void*)&Param);
	
	// return true;
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);

	TestTrue("It's the same", Result.Equals(ExpectedResult));
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldCallVoidFuncWithNoArgs, "NimForUETest.ShouldCallVoidFuncWithNoArgs", TestFlags)
bool ShouldCallVoidFuncWithNoArgs::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	void* Param = nullptr;
	UFunction* Function = TestObject->FindFunction(FName("ModifiedWasCalled"));
	UFunctionCaller FunctionCaller (Function, (void*)&Param);
	
	// return true;
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);

	TestTrue("It's the same", TestObject->bWasCalled);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleIntInputsAndOutputs, "NimForUETest.ShouldHandleIntInputsAndOutputs", TestFlags)
bool ShouldHandleIntInputsAndOutputs::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	auto Params = MakeTuple(5, 5);
	int ExpectedResult = TestObject->Add(Params.Get<0>(), Params.Get<1>());
	
	UFunction* Function = TestObject->FindFunction(FName("Add"));
	UFunctionCaller FunctionCaller (Function, (void*)&Params);
	
	int Result;
	FunctionCaller.Invoke(TestObject, &Result);
	
	TestTrue("It's the same", Result == ExpectedResult);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleObjecsReturns, "NimForUETest.ShouldHandleObjecsReturns", TestFlags)
bool ShouldHandleObjecsReturns::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	UFunction* Function = TestObject->FindFunction(FName("MakeReturnClass"));
	
	UFunctionCaller FunctionCaller (Function, nullptr);
	

	UMyReturnClass* Result;
	FunctionCaller.Invoke(TestObject, &Result);
	
	TestTrue("It's the same", Result->bWasReturned);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleObjectInputs, "NimForUETest.ShouldHandleObjectInputs", TestFlags)
bool ShouldHandleObjectInputs::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	UFunction* Function = TestObject->FindFunction(FName("SendAsInput"));
	UMyReturnClass* Object = NewObject<UMyReturnClass>();
	
	UFunctionCaller FunctionCaller (Function, Object);
	
	FunctionCaller.Invoke(TestObject);
	
	TestTrue("It's the same", Object->bWasModified);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleArbitraryCombinationOfTypes, "NimForUETest.ShouldHandleArbitraryCombinationOfTypes", TestFlags)
bool ShouldHandleArbitraryCombinationOfTypes::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	UFunction* Function = TestObject->FindFunction(FName("GetObjectNameNTimes"));
	UMyReturnClass* Object = NewObject<UMyReturnClass>();
	int64 Times = 5;
	
	auto Params = MakeTuple(Object, Times);
	UFunctionCaller FunctionCaller (Function, &Params);
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);
	

	
	FString ExpectedResult = TestObject->GetObjectNameNTimes(Params.Get<0>(), Params.Get<1>());
	UE_LOG(LogTemp, Warning, TEXT("The return value is %s"), *Result)
	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *ExpectedResult)

	TestEqual("It's the same", Result,  ExpectedResult);
	return true;
};


IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleArbitraryCombinationOfTypesSwappingParameters, "NimForUETest.ShouldHandleArbitraryCombinationOfTypesSwappingParameters", TestFlags)
bool ShouldHandleArbitraryCombinationOfTypesSwappingParameters::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	UFunction* Function = TestObject->FindFunction(FName("GetObjectNameNTimes2"));
	UMyReturnClass* Object = NewObject<UMyReturnClass>();
	int64 Times = 5;
	
	auto Params = MakeTuple(Times, Object, TestObject);
	UFunctionCaller FunctionCaller (Function, &Params);
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);
	

	
	FString ExpectedResult = TestObject->GetObjectNameNTimes2(Params.Get<0>(), Params.Get<1>(), Params.Get<2>());
	UE_LOG(LogTemp, Warning, TEXT("The return value is %s"), *Result)
	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *ExpectedResult)

	TestEqual("It's the same", Result,  ExpectedResult);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleTheSignature_FString_Int_Ret_FString, "NimForUETest.ShouldHandleTheSignature_FString_Int_Ret_FString", TestFlags)
bool ShouldHandleTheSignature_FString_Int_Ret_FString::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		FString Param;
		int Test;
	};
	
	Params Parms = { "hola", 5};
	FString ExpectedResult = TestObject->TestReturnStringWithParams(Parms.Param, Parms.Test);
	
	UFunction* Function = TestObject->FindFunction(FName("TestReturnStringWithParams"));
	UFunctionCaller FunctionCaller (Function, (void*)&Parms);
	
	FString Result;
	FunctionCaller.Invoke(TestObject, &Result);

	UE_LOG(LogTemp, Warning, TEXT("The return value is %s"), *Result)
	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *ExpectedResult)
	TestTrue("It's the same", Result == ExpectedResult);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleTheSignature_FString_Int_OUT_FString, "NimForUETest.ShouldHandleTheSignature_FString_Int_OUT_FString", TestFlags)
bool ShouldHandleTheSignature_FString_Int_OUT_FString::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		FString Param;
		int Test;
		FString Out;
	};
	Params Parms = { "hola", 5};
	Params Parms2 = { "hola", 5};
	
	TestObject->TestReturnStringWithParamsOut(Parms.Param, Parms.Test, Parms.Out);
	
	FString FunctionName = "TestReturnStringWithParamsOut";
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms2, nullptr);

	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *Parms.Out);
	UE_LOG(LogTemp, Warning, TEXT("The out value is %s"), *Parms2.Out);
	TestTrue("It's the same", Parms.Out == Parms2.Out);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleTheSignature_Floats, "NimForUETest.ShouldHandleTheSignature_Floats", TestFlags)
bool ShouldHandleTheSignature_Floats::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		float A;
		float B;
	};
	Params Parms = { 2.1f, 2.f};
	
	
	float ExpectedResult = TestObject->SumFloats(Parms.A, Parms.B);
	float Result;
	FString FunctionName = "SumFloats";
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms, &Result);


	TestTrue("It's the same", Result == ExpectedResult);
	return true;
};

//Issue reproduction
IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleTheSignature_FString_Int_RetFString, "NimForUETest.ShouldHandleTheSignature_FString_Int_RetFString", TestFlags)
bool ShouldHandleTheSignature_FString_Int_RetFString::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		FString A;
		int B;
	};
	Params Parms = { "Hello", 5};
	
	
	FString ExpectedResult = TestObject->TestMultipleParams(Parms.A, Parms.B);
	FString Result;
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, TestMultipleParams).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms, &Result);

	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *ExpectedResult);
	TestTrue("It's the same", Result == ExpectedResult);
	return true;
};
