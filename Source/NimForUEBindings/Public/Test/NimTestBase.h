#include "Misc/AutomationTest.h"


class NIMFORUEBINDINGS_API FNimTestBase : public FAutomationTestBase {
public:
	// virtual ~FNimTestBase() override;
	// virtual FString GetTestFullName() const override;
	// virtual void AddError(const FString& InError, int32 StackOffset) override;
	// virtual void AddErrorIfFalse(bool bCondition, const FString& InError, int32 StackOffset) override;
	// virtual void AddErrorS(const FString& InError, const FString& InFilename, int32 InLineNumber) override;
	// virtual void AddWarningS(const FString& InWarning, const FString& InFilename, int32 InLineNumber) override;
	// virtual void AddWarning(const FString& InWarning, int32 StackOffset) override;
	// virtual void AddInfo(const FString& InLogItem, int32 StackOffset) override;
	// virtual void AddEvent(const FAutomationEvent& InEvent, int32 StackOffset) override;
	// virtual void AddAnalyticsItem(const FString& InAnalyticsItem) override;
	// virtual void AddTelemetryData(const FString& DataPoint, double Measurement, const FString& Context) override;
	// virtual void AddTelemetryData(const TMap<FString, double>& ValuePairs, const FString& Context) override;
	// virtual void SetTelemetryStorage(const FString& StorageName) override;
	// virtual bool SuppressLogs() override;
	// virtual bool SuppressLogErrors() override;
	// virtual bool SuppressLogWarnings() override;
	// virtual bool ElevateLogWarningsToErrors() override;
	// virtual FString GetTestSourceFileName(const FString& InTestName) const override;
	// virtual int32 GetTestSourceFileLine(const FString& InTestName) const override;
	// virtual FString GetTestAssetPath(const FString& Parameter) const override;
	// virtual FString GetTestOpenCommand(const FString& Parameter) const override;
protected:
	// virtual void SetTestContext(FString Context) override;
private:
	FString TestName;
public:
	
	FNimTestBase(FString InName) : FAutomationTestBase(InName, false) {
		TestName = InName;
	}
	
	FNimTestBase() :FAutomationTestBase("InName", false) {
	}

	void (*ActualTest) (FNimTestBase&);

	void ReloadTest();
	
	virtual uint32 GetTestFlags() const override {
		//At some point expose these
		return  EAutomationTestFlags::EditorContext | EAutomationTestFlags::SmokeFilter;;
	}
	virtual FString GetBeautifiedTestName() const override {
		return TestName;
	}
	virtual bool RunTest(const FString& Parameters) override {
		if(ActualTest!=nullptr) {
			ActualTest(*this);
		}
		return true;
	}
	virtual bool IsStressTest() const { return false; }
	
	virtual uint32 GetRequiredDeviceNum() const override { return 1; } 
	virtual FString GetTestSourceFileName() const override { return "Whatever.cpp"; } 
	virtual int32 GetTestSourceFileLine() const override { return 10; } 
protected: 
	virtual void GetTests(TArray<FString>& OutBeautifiedNames, TArray <FString>& OutTestCommands) const override 
	{ 
		OutBeautifiedNames.Add(TestName); 
		OutTestCommands.Add(FString());
		
	}

};

