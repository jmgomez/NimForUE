#include "Test/NimTestBase.h"

void FNimTestBase::ReloadTest() {
	FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
	FAutomationTestFramework::Get().RegisterAutomationTest(TestName, this );

}
