using System.IO;
using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	public NimForUEBindings(ReadOnlyTargetRules Target) : base(Target) {
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine",
			"Projects",
			"UMG",
			"NavigationSystem",
			//"UnrealEd"
			 "InputCore", 
			 //THE PCH pulls the headers from this module. So the search paths should be in here
			 //maybe it's a good idea to have this templated so we can add more modules. without changing the PCH
			 //TODO: Get the modules from the host dll. So the user can specify them via game.json
			 "EnhancedInput", "GameplayAbilities",
			 
			
		});
		
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
		var PCHFile = Path.Combine(nimHeadersPath, "bindingsbase.h");
		PublicIncludePaths.Add(nimHeadersPath);
		PrivatePCHHeaderFile = PCHFile;
		bUseUnity = false;
		
	}
}



