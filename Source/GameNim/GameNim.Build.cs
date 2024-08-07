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
			"UnrealEd",
			"EditorStyle",
			"Slate",
			"SlateCore",
			"NimForUEBindings"
			
		});
		PrivateDependencyModuleNames.AddRange(new string[] {
			"Kismet",
			"BlueprintGraph","ToolMenus", "Projects"
		});
		
	}

}