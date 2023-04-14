using System.IO;
using UnrealBuildTool;
 
public class NimForUEGame : ModuleRules
{
	public NimForUEGame(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"InputCore", 
			"Slate", 
			"SlateCore",
			"Engine", 
			"NimForUEBindings",
			"EnhancedInput", 
			"GameplayTags",
			"PCG",
			"GameplayAbilities",
			"PhysicsCore",
			"UnrealEd",
			"NimForUE", //DUE To reinstance bindigns. So editor only
			
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
	
		PublicDefinitions.Add("NIM_INTBITS=64");
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		} else {
			CppStandard = CppStandardVersion.Cpp17;
		}
		PrivatePCHHeaderFile = "../../NimHeaders/nimgame.h";
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		PublicIncludePaths.Add(nimHeadersPath);
		bUseUnity = false;
		//The lib is quite big (24MB), it may be better to just pull the files that needs to be compiled
		// var nimMirrorBindings = Path.Combine(PluginDirectory, "Binaries", "nim", "libmaingencppbindings.a");
		var nimMirrorBindings = Path.Combine(PluginDirectory, "Binaries", "nim", "maingencppbindings.lib");
		// PublicAdditionalLibraries.Add(nimMirrorBindings);
	}
}