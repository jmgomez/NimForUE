// Copyright Epic Games, Inc. All Rights Reserved.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using UnrealBuildTool;



public class NimForUE : ModuleRules
{
	//Bind a few methods to set the EngineDir, Platform, etc.
	
	public NimForUE(ReadOnlyTargetRules Target) : base(Target) {
	    PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		} else {
			CppStandard = CppStandardVersion.Cpp17;
		}
		//Console.WriteLine((Path.GetFullPath(PluginDirectory + "NimForUE\\..\\NimHeaders")));
	    //PublicIncludePaths.Add(Path.GetFullPath(PluginDirectory + "NimForUE\\..\\NimHeaders"));
	    //PublicIncludePaths.Add("../../Intermediate\Build\Mac\x86_64\UnrealEditor\DebugGame\NimForUEBindings");
        PublicDefinitions.Add("NIM_INTBITS=64");
	    PrivatePCHHeaderFile = "../../NimHeaders/nimbase.h";	
	    
	    OptimizeCode = CodeOptimization.InShippingBuildsOnly;
	    Console.WriteLine("Linker arguments:");
		
	    Console.WriteLine(Target.AdditionalLinkerArguments);
		PublicIncludePaths.AddRange(   
			new string[] {
				
			}
			);
				
		
		PrivateIncludePaths.AddRange(
			new string[] {
				// ... add other private include paths required here ...
			}
			);
			
		
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput" });


		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[]{
				"UnrealEd",
				"NimForUEEditor",
				
			});
		}

		PrivateDependencyModuleNames.AddRange(
			new string[]
			{
				"CoreUObject",
				"Engine",
				"Slate",
				"SlateCore",
				
				"NimForUEBindings",
				"EditorStyle",
				"Projects",
				"EnhancedInput"
			
			}
			);
		
		
		DynamicallyLoadedModuleNames.AddRange(
			new string[]
			{
				// ... add any modules that your module loads dynamically here ...
			}
			);

		// CppStandard = CppStandardVersion.Cpp14;
		//TODO This is only for dev. Research build path. Especially for platforms like iOS
		AddNimForUEDev();
		

	}

	
	


	
	[DllImport("hostnimforue")]
	public static extern void setNimForUEConfig(string pluginDir, string engineDir, string platform, string config);
	
	//WIN ONLY
	[DllImport("kernel32.dll")]
	static extern bool SetDllDirectory(string lpPathName);

	//TODO Run buildlibs from here so the correct config/platform is picked when building
	void AddNimForUEDev() { //ONLY FOR WIN/MAC with EDITOR (dev) target

		var nimBinPath = Path.Combine(PluginDirectory, "Binaries", "nim", "ue");
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		string dynLibPath;
		var isWin = Target.Platform == UnrealTargetPlatform.Win64;
		if (isWin) {
			var dllName = "hostnimforue.dll";
			dynLibPath = Path.Combine(nimBinPath, dllName);
			SetDllDirectory(nimBinPath);
			var libSymbolsName = "hostnimforue.lib";
			RuntimeDependencies.Add(dynLibPath);
			PublicDelayLoadDLLs.Add(dllName);
			PublicAdditionalLibraries.Add(Path.Combine(nimBinPath, libSymbolsName));
			
			
		}
		else {
			dynLibPath = Path.Combine(nimBinPath, "libhostnimforue.dylib");
			PublicAdditionalLibraries.Add(dynLibPath);
		}
		PublicIncludePaths.Add(nimHeadersPath);
		
		
		//PublicDefinitions.Add($"NIM_FOR_UE_LIB_PATH  \"{dynLibPath}\"");
		//TRY?
		try {
			//BuildNim();
			//setNimForUEConfig(PluginDirectory, EngineDirectory, Target.Platform.ToString(), Target.Configuration.ToString());
		}
		catch (Exception e) {
			Console.WriteLine("There was a problem trying to load Nim. Attention, make sure the EngineDir is set. Otherwise NimForUE wont compile.");
			Console.WriteLine(e.Message);
			Console.WriteLine(e.StackTrace);
			//TODO Print JSON Here
			
		}
	}
	

	void BuildNim(){
		var isWin = Target.Platform == UnrealTargetPlatform.Win64;
		var processInfo = new ProcessStartInfo();
		
		processInfo.WorkingDirectory = Path.Combine(PluginDirectory, "src", "buildscripts");
		if (isWin) {
			processInfo.FileName = "cmd.exe";
			processInfo.Arguments = "/c buildlibs.bat";
		}
		else {
			processInfo.FileName = "sh";
			processInfo.Arguments = "buildlibs.sh";
		}
		//
		var process = Process.Start(processInfo);
		process.WaitForExit();
		}
}
