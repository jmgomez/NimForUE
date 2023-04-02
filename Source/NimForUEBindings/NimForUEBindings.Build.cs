using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	public NimForUEBindings(ReadOnlyTargetRules Target) : base(Target) {
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine",
			"Projects",
			//"UnrealEd"
			 "InputCore", 
			 //THE PCH pulls the headers from this module. So the search paths should be in here
			 //maybe it's a good idea to have this templated so we can add more modules. without changing the PCH
			 "EnhancedInput", "GameplayAbilities",
			 
			
		});
		
#if UE_5_2_OR_LATER
		PublicDependencyModuleNames.Add("PCG");
		
#endif
		bEnableExceptions = true;
		

		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
			});
		}
	}
}



