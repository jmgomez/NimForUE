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
        PublicDefinitions.Add("WITH_STARTNUE=0");
	    PrivatePCHHeaderFile = "../../NimHeaders/nimbase.h";	
	    
	    OptimizeCode = CodeOptimization.InShippingBuildsOnly;
	    Console.WriteLine("Linker arguments:");
		
	    Console.WriteLine(Target.AdditionalLinkerArguments);
	

		PublicIncludePathModuleNames.Add("GameplayAbilities");
	
		
		PublicDependencyModuleNames.AddRange(new string[] { 
			"GameplayAbilities",
			"Core", "CoreUObject", "Engine", "InputCore", "NavigationSystem", 
		
		});


		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[]{
				"UnrealEd",
				"NimForUEEditor",
				"EditorStyle",
			});
		}

		PrivateDependencyModuleNames.AddRange(
			new string[] {
				"CoreUObject",
				"Engine",
				"Slate",
				"SlateCore",

				"NimForUEBindings",
				
				"Projects",
			

			}
		);
		


		DynamicallyLoadedModuleNames.AddRange(
			new string[]
			{
				// ... add any modules that your module loads dynamically here ...
			}
			);
		
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		PublicIncludePaths.Add(nimHeadersPath);
		
		if (Target.bBuildEditor)
			AddNimForUEDev();
		
		// bStrictConformanceMode = true;
		bUseUnity = false;
	}


	[DllImport("hostnimforue")]
	public static extern void setWinCompilerSettings(string sdkVersion, string compilerVersion, string toolchainDir);

	[DllImport("libhostnimforue")]
	public static extern void setUEConfig(string engineDir,string conf,string platform, bool withEditor);
	
	//WIN ONLY
	[DllImport("kernel32.dll")]
	static extern bool SetDllDirectory(string lpPathName);

	void NimbleSetup() {
		var processInfo = new ProcessStartInfo();
		processInfo.WorkingDirectory = PluginDirectory;
		Console.WriteLine("Running nimble setup in", PluginDirectory);
		processInfo.FileName = "nimble" + (Target.Platform == UnrealTargetPlatform.Win64 ? ".exe" : ""); 
		processInfo.Arguments = "ok";
		try {
			var process = Process.Start(processInfo);
			process.WaitForExit();
			var nimBinPath = Path.Combine(PluginDirectory, "Binaries", "nim", "ue", "libhostnimforue.dylib");
			Console.WriteLine((Target.ProjectFile.Directory.ToString()));
			//setUEConfig(EngineDirectory, Target.Configuration.ToString(), Target.Platform.ToString(), Target.bBuildEditor);
		}
		

		catch (Exception e) {
			Console.WriteLine("There was a problem trying to run nimble.");
			Console.WriteLine(e.Message);
			Console.WriteLine(e.StackTrace);
		}
	}

	//TODO Run buildlibs from here so the correct config/platform is picked when building
	void AddNimForUEDev() { //ONLY FOR WIN/MAC with EDITOR (dev) target
		NimbleSetup(); //Make sure NUE and Host are built
		var nimBinPath = Path.Combine(PluginDirectory, "Binaries", "nim", "ue");
		

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
		
		
		//PublicDefinitions.Add($"NIM_FOR_UE_LIB_PATH  \"{dynLibPath}\"");
		//TRY?
		try {
			//BuildNim();
			//setNimForUEConfig(PluginDirectory, EngineDirectory, Target.Platform.ToString(), Target.Configuration.ToString());
			if (Target.Platform == UnrealTargetPlatform.Win64)
				setWinCompilerSettings(Target.WindowsPlatform.WindowsSdkVersion, Target.WindowsPlatform.CompilerVersion, Target.WindowsPlatform.ToolChainDir);
			Console.WriteLine(Target.WindowsPlatform.ToolChainDir);	
			Console.WriteLine(Target.WindowsPlatform.ToolChainDir);	
			Console.WriteLine(Target.WindowsPlatform.CompilerVersion);	
			//setUEConfig(
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
