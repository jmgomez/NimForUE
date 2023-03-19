// Fill out your copyright notice in the Description page of Project Settings.


#include "EditorExtensions.h"

#include "ReflectionHelpers.h"
#include "Interfaces/IPluginManager.h"
#include "Styling/SlateStyleRegistry.h"

#define LOCTEXT_NAMESPACE "NimForUEScriptEditor"
#define PLUGIN_IMAGE_BRUSH( RelativePath, ... ) FSlateImageBrush( InResource( RelativePath, ".png" ), __VA_ARGS__ )

FString InResource(const FString& RelativePath, const ANSICHAR* Extension) {
	static FString ResourcesDir = IPluginManager::Get().FindPlugin(TEXT("NimForUE"))->GetBaseDir() /
		TEXT("Resources");
	return (ResourcesDir / RelativePath) + Extension;
}

FStyle::FStyle() : FSlateStyleSet(TEXT("NimForUEStyleSet")) {
	
}

void FStyle::Initialize() {
	const FVector2D Icon36x36(36.0f, 36.0f);
	const FVector2D Icon80x80(80.0f, 80.0f);
	Set("NimForUE.Toolbar.NimScripReload", new PLUGIN_IMAGE_BRUSH("nim_icon_80", Icon80x80));

}
bool UEditorExtensions::bIsInit = false;

void UEditorExtensions::AddReloadScriptButtom() {
	if (IsRunningCommandlet()) return;
	UEditorExtensions* This = Cast<UEditorExtensions>(UEditorExtensions::StaticClass()->GetDefaultObject());
	This->Init();
	
	UToolMenu* AssetsToolBar = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar.AssetsToolBar");
	if (AssetsToolBar) {
		FToolMenuSection& Section = AssetsToolBar->AddSection("Content");
		FToolMenuEntry LaunchPadEntry =
			FToolMenuEntry::InitToolBarButton("Nim", FUIAction(FExecuteAction::CreateStatic([]() {
				UClass* NimVmManager = UReflectionHelpers::GetClassByName("NimVMManager");
				if (!NimVmManager) return;
				UFunction* ReloadScript = NimVmManager->FindFunctionByName("ReloadScript");
				if (!ReloadScript) return;
				NimVmManager->GetDefaultObject()->ProcessEvent(ReloadScript, nullptr);
			})),        //FDALevelToolbarCommands::Get().OpenLaunchPad,
			LOCTEXT("NimForUEScriptEditor_1", "Reload NimScript"),
			LOCTEXT("NimForUEScriptEditor_Tooltip", "Reload the script defined in the NimVM"),
			FSlateIcon("NimForUEStyleSet", "NimForUE.Toolbar.NimScripReload"));
																					
		LaunchPadEntry.StyleNameOverride = "CalloutToolbar";
		Section.AddEntry(LaunchPadEntry);
	}
}

void UEditorExtensions::Init() {
	if(bIsInit)
		return;
	bIsInit = true;
	Style = new FStyle;
	Style->Initialize();
	FSlateStyleRegistry::RegisterSlateStyle(*Style);
}
