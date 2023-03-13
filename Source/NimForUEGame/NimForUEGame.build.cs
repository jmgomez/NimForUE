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
	
	}
}