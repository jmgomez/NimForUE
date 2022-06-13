using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	public NimForUEBindings(ReadOnlyTargetRules Target) : base(Target)
	{

		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PrivatePCHHeaderFile = "../../NimHeaders/UEDeps.h";
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;

		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine",
			//"UnrealEd"
			
		});
	}
}



