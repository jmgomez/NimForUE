using UnrealBuildTool;
 
public class NimForUETest : ModuleRules
{
	public NimForUETest(ReadOnlyTargetRules Target) : base(Target)
	{
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
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