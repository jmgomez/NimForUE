using System.IO;
using UnrealBuildTool;
 
public class NimForUEEditor : ModuleRules
{
	public NimForUEEditor(ReadOnlyTargetRules Target) : base(Target) {
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core",
			"CoreUObject",
			"Engine",
			"UnrealEd",
			"Slate",
			"SlateCore",
			"NimForUEBindings"
			
		});
		PrivateDependencyModuleNames.AddRange(new string[] {
			"Kismet",
			"BlueprintGraph",
		});

	}

}