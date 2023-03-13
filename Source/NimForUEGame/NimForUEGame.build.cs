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
			"Engine", 
			"NimForUEBindings"
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
	
		PublicDefinitions.Add("NIM_INTBITS=64");

		PrivatePCHHeaderFile = "../../NimHeaders/nimbase.h";
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		PublicIncludePaths.Add(nimHeadersPath);
		bUseUnity = false;

	}
}