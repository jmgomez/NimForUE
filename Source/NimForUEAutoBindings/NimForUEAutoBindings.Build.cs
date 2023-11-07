using System.IO;
using UnrealBuildTool;

public class NimForUEAutoBindings : ModuleRules
{
	public NimForUEAutoBindings(ReadOnlyTargetRules Target) : base(Target) {
		
		PublicDependencyModuleNames.AddRange(new string[] {
			"GameplayAbilities",
			"Core", "CoreUObject", "Engine", "InputCore", "NavigationSystem",
			"Slate", "UMG",
			"SlateCore", "EnhancedInput", "GameplayAbilities", "GameplayTasks", "GameplayTags"

		});


		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
				"NimForUEEditor",
				"EditorStyle",
				"AdvancedPreviewScene",
			});
		}

		PrivateDependencyModuleNames.AddRange(
			new string[] {
				"CoreUObject",
				"Engine",
				"NimForUEBindings",
				"Projects",
			}
		);

		
#if UE_5_2_OR_LATER
		PublicDependencyModuleNames.Add("PCG");
		
#endif

		if (Target.bBuildEditor) {
			PublicDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
				"AdvancedPreviewScene"
			});
		}
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		}
		else {
			CppStandard = CppStandardVersion.Cpp17;
		}

		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		PublicDefinitions.Add("NIM_INTBITS=64");
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		// var PCHFile = Path.Combine(nimHeadersPath, "bindingsbase.h");
		PublicIncludePaths.Add(nimHeadersPath);
		// PrivatePCHHeaderFile = PCHFile;
		bUseUnity = false;
		
	}
}



