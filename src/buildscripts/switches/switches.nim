
import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]
when defined(macosx):
  import macswitches
  export macswitches
elif defined(windows):
  import winswitches
  export winswitches
else:
  quit("Platform not supported")


let config = getNimForUEConfig()
const withPCH* = true 
#TODO Only PCH works in windows. 
#Regular builds need to be fixed
#but since we are using unreal PCH it shouldnt be a big deal

let ueincludes* = getUEHeadersIncludePaths(config).map(headerPath => "-t:-I" & escape(quotes(headerPath)))
let uesymbols* = getUESymbols(config).map(symbolPath => "-l:" & escape(quotes(symbolPath)))

let buildSwitches* = @[
  "--outdir:./Binaries/nim/",
  "--mm:orc",
  "--backend:cpp",
  "--exceptions:cpp",# & (if WithEditor: "cpp" else: "quirky"),
  "--warnings:off",
  "--ic:off",
  "--threads:off",
  "--path:$nim",
  "--parallelBuild:0",
  "-d:nimOldCaseObjects", #Nim 2.0 
  
  # "--hints:off",
  "--hint:XDeclaredButNotUsed:off",
  "--hint:Name:off",
  "--hint:DuplicateModuleImport:off",
  # "-d:useMalloc",

  "-d:withReinstantiation",
  "-d:genFilePath:" & quotes(GenFilePath),
  "-d:pluginDir:" & quotes(PluginDir),
  "-d:withEditor:" & $WithEditor,
]

#Probably this needs to be platform specific as well
proc targetSwitches*(withDebug: bool): seq[string] =
  result = 
    case config.targetConfiguration:
    of Debug, Development:
      var ts = @["--opt:none"]
      if withDebug:
        ts &= @["--stacktrace:on"]
        if not defined(windows):
          ts &= @["--debugger:native"]
        else: #"--debugger:native" == --lineDir:on + --debugInfo
        #in windows they use -Zi and we manually pass over Z7 (because of UE PCH) so we only set --lineDir:on
          ts &= @["--linedir:on"]#, "--debugInfo"]
        
      ts & @["--stacktrace:on", "--linedir:on"]
    of Shipping: @["--danger"]
  result.add @[
    "--nimBasePattern:nuebase.h",
    "--cincludes:" & quotes(PluginDir / "NimHeaders")
  ]


proc hostPlatformSwitches*(withDebug: bool): seq[string] = getPlatformSwitches(false, true, "")
proc pluginPlatformSwitches*(withDebug: bool): seq[string] = getPlatformSwitches(withPch, withDebug, "guest") 
proc gamePlatformSwitches*(withDebug: bool): seq[string] = getPlatformSwitches(withPch, withDebug, "game") 

