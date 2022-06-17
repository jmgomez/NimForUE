#include "Test/NimTestBase.h"

void FNimTestBase::UnregisterAll() {
	for(FString TestName : AllRegisteredNimTests) {
		FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
	}
}

void FNimTestBase::ReloadTest() {
	FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
	FAutomationTestFramework::Get().RegisterAutomationTest(TestName, this );
	AllRegisteredNimTests.AddUnique(TestName);
}
