using System.IO;
using UnrealBuildTool;
 
public class GameNim : ModuleRules
{
	public GameNim(ReadOnlyTargetRules Target) : base(Target) {
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core",
			"CoreUObject",
			"Engine",
			"Slate",
			"SlateCore",
			"NimForUEBindings"
		});
		
		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd", 			
				"EditorStyle"
			});
			PrivateDependencyModuleNames.AddRange(new string[] {
			"Kismet", "BlueprintGraph","ToolMenus", "Projects"
		});
		}
	}

}