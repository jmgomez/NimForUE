
//
#include "TestUtils.h"
#include "UFunctionCaller.h"
#include "Misc/AutomationTest.h"
#include "NimForUEFFI.h"
#include "NimForUETest/Public/TestObjects/FunctionTestObject.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FNimForUETestSpec, "NimForUETest.NaiveTest", TestFlags)
bool FNimForUETestSpec::RunTest(const FString& Parameters) {
	
	TestTrue("SPECS ARE EQUAL", true);
    UE_LOG(LogTemp, Warning, TEXT("Size of int %i"), sizeof(int));
    UE_LOG(LogTemp, Warning, TEXT("Size of char %i"), sizeof(char));
    UE_LOG(LogTemp, Warning, TEXT("Size of FString %i"), sizeof(FString));
    UE_LOG(LogTemp, Warning, TEXT("Size of Pointer %i"), sizeof(UObject*));
    UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char> %i"), sizeof(TTuple<int, char>));
    UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char, UObject*> %i"), sizeof(TTuple<int, char, UObject*>));
    UE_LOG(LogTemp, Warning, TEXT("Size of TTuple<int, char, UObject*, FString> %i"), sizeof(TTuple<int, char, UObject*, FString>));
    // UE_LOG(LogTemp, Warning, TEXT("Size of EObject %i"), sizeof(TTuple<int, char, UObject*, FString>));
	return true;
};

// // //FIND SHORTER TESTS DECLARATION

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToHandleFStringAsArgumentAndOutPut, "NimForUETest.ShouldBeAbleToHandleFStringAsArgumentAndOutPut", TestFlags)
bool ShouldBeAbleToHandleFStringAsArgumentAndOutPut::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	struct Params {
		FString Param = "Test";
		FString Result;
	};
	Params Param;
	FString ExpectedResult = TestObject->GetStringTwice(Param.Param);

	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, GetStringTwice).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Param);
	
	bool Test = Param.Result.Equals(ExpectedResult);
	TestTrue("It's the same", Param.Result.Equals(ExpectedResult));
	return true;
};


// // //
IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput, "NimForUETest.ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput", TestFlags)
bool ShouldBeAbleToHandleTwoFStringsParameterAndOneOutput::RunTest(const FString& Parameters) {


	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	struct Params {
		FString Param = "Test1";
		FString Params2 = "Test2";
		FString Result;
	};
	Params Param;
	FString ExpectedResult = TestObject->AddStrings(Param.Param, Param.Params2);

	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, AddStrings).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Param);
	
	TestTrue("It's the same", Param.Result.Equals(ExpectedResult));
	return true;

};


IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldCallVoidFuncWithNoArgs, "NimForUETest.ShouldCallVoidFuncWithNoArgs", TestFlags)
bool ShouldCallVoidFuncWithNoArgs::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	
	UFunction* Function = TestObject->FindFunction(FName("ModifiedWasCalled"));
	UFunctionCaller FunctionCaller (Function, nullptr);
	

	FunctionCaller.Invoke(TestObject);

	TestTrue("It's the same", TestObject->bWasCalled);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleArbitraryCombinationOfTypes, "NimForUETest.ShouldHandleArbitraryCombinationOfTypes", TestFlags)
bool ShouldHandleArbitraryCombinationOfTypes::RunTest(const FString& Parameters) {
	
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	struct Params {
		UMyReturnClass* Object = NewObject<UMyReturnClass>();
		int64 Times = 5;
		FString Result;
	};
	Params Param;
	FString ExpectedResult = TestObject->GetObjectNameNTimes(Param.Object, Param.Times);


	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, GetObjectNameNTimes).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Param);
	
	TestTrue("It's the same", Param.Result.Equals(ExpectedResult));
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
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms2);

	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *Parms.Out);
	UE_LOG(LogTemp, Warning, TEXT("The out value is %s"), *Parms2.Out);
	TestTrue("It's the same", Parms.Out == Parms2.Out);
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_Bool, "NimForUETest.ShouldHandleDataType_Bool", TestFlags)
bool ShouldHandleDataType_Bool::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		bool A;
		bool B;
		bool Result;
	};
	Params Parms = { true, false};
	
	
	bool ExpectedResult = TestObject->OR(Parms.A, Parms.B);
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, OR).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);
	
	TestTrue("It's the same", Parms.Result == ExpectedResult);
	return true;
};




IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_TArrayInt_AsArgument, "NimForUETest.ShouldHandleDataType_TArrayInt_AsArgument", TestFlags)
bool ShouldHandleDataType_TArrayInt_AsArgument::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		TArray<int> ArrayInts;
		int Result;
	};
	Params Parms = { {2, 4, 5, 1}};
	
	
	int ExpectedResult = TestObject->ArrayLength(Parms.ArrayInts);
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, ArrayLength).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);

	TestTrue("It's the same", Parms.Result == ExpectedResult);
	return true;
};
//STRING ALLOCATION 
IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_TArrayFString_AsArgument, "NimForUETest.ShouldHandleDataType_TArrayFString_AsArgument", TestFlags)
bool ShouldHandleDataType_TArrayFString_AsArgument::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();
	struct Params {
		TArray<FString> Words;
		FString Result;
	};
	TArray<FString> Arr = {FString("hola"), FString("oho"), FString("asd"), FString("hi")};
	Params Parms;
	Parms.Words = Arr;
	
	FString ExpectedResult = TestObject->Reduce(Parms.Words);

	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, Reduce).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);

	UE_LOG(LogTemp, Warning, TEXT("The expected value is %s"), *ExpectedResult);
	UE_LOG(LogTemp, Warning, TEXT("The out value is %s"), *Parms.Result);
	TestTrue("It's the same", Parms.Result.Equals(ExpectedResult));
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_TStruct, "NimForUETest.ShouldHandleDataType_TStruct", TestFlags)
bool ShouldHandleDataType_TStruct::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		FMyStructParam MyStruct;
		int Result;
	};
	Params Parms = {{2}};
	
	
	int ExpectedResult = TestObject->GetValueFromStruct(Parms.MyStruct);
	
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, GetValueFromStruct).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);

	TestTrue("It's the same", Parms.Result == (ExpectedResult));
	return true;
};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_TStructStr, "NimForUETest.ShouldHandleDataType_TStructStr", TestFlags)
bool ShouldHandleDataType_TStructStr::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		FMyStructParamWithStr MyStruct;
		FString Result;
	};
	Params Parms = {{2, FString("Test")}};
	
	
	FString ExpectedResult = TestObject->GetStrValueFromStruct(Parms.MyStruct);
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, GetStrValueFromStruct).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);

	TestTrue("It's the same", Parms.Result == (ExpectedResult));
	return true;
};


IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldHandleDataType_TArray, "NimForUETest.ShouldHandleDataType_TArray", TestFlags)
bool ShouldHandleDataType_TArray::RunTest(const FString& Parameters) {
	UFunctionTestObject* TestObject = NewObject<UFunctionTestObject>();

	struct Params {
		TArray<int> ArrayInts;
		TArray<FString> Result;
	};
	Params Parms = { {2, 4, 5, 1}};
	
	TArray<FString> ExpectedResult = TestObject->ArrayIntsToArrayStrings(Parms.ArrayInts);
	
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, ArrayIntsToArrayStrings).ToString();
	UFunctionCaller::CallUFunctionOn(TestObject, FunctionName, &Parms);

	TestTrue("It's the same", Parms.Result == ExpectedResult);
	return true;
};


IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldBeAbleToCallStaticMethodsWihoutExecutor, "NimForUETest.ShouldBeAbleToCallStaticMethodsWihoutExecutor", TestFlags)
bool ShouldBeAbleToCallStaticMethodsWihoutExecutor::RunTest(const FString& Parameters) {
	

	struct Params {
		TArray<int> ArrayInts;
		int Result;
	};
	Params Parms = { {2, 4, 5, 1}};
	
	
	int ExpectedResult = UFunctionTestObject::StaticArrayLength(Parms.ArrayInts);
	FString FunctionName = GET_FUNCTION_NAME_CHECKED(UFunctionTestObject, StaticArrayLength).ToString();
	UFunctionCaller::CallUFunctionOn(UFunctionTestObject::StaticClass(), FunctionName, &Parms);

	TestTrue("It's the same", Parms.Result == ExpectedResult);
	return true;
};