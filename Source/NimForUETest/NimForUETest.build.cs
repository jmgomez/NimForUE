using UnrealBuildTool;
 
public class NimForUETest : ModuleRules
{
	public NimForUETest(ReadOnlyTargetRules Target) : base(Target)
	{
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PrivateIncludePaths.Add("../NimForUEBindings/Private");
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine", 
			"UnrealEd",
			"NimForUEBindings"
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
		
	}
}