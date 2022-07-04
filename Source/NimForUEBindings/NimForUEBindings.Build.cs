using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	public NimForUEBindings(ReadOnlyTargetRules Target) : base(Target)
	{
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine",
			
			//"UnrealEd"
			
		});
	}
}



