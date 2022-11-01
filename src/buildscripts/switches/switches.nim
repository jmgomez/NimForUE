
import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig, nimcachebuild]
when defined(macosx):
  import macswitches
  export macswitches
elif defined(windows):
  import winswitches
  export winswitches
else:
  quit("Platform not supported")


let config = getNimForUEConfig()
const withDebug* = true
const withPCH* = true 
#TODO Only PCH works in windows. 
#Regular builds need to be fixed
#but since we are using unreal PCH it shouldnt be a big deal

let ueincludes* = getUEHeadersIncludePaths(config).map(headerPath => "--t:-I" & escape(quotes(headerPath)))
let uesymbols* = getUESymbols(config).map(symbolPath => "-l:" & escape(quotes(symbolPath)))

let buildSwitches* = @[
  "--outdir:./Binaries/nim/",
  "--mm:orc",
  "--backend:cpp",
  "--exceptions:cpp",
  "--warnings:off",
  "--ic:off",
  "--threads:off",
  "--path:$nim",
  # "--hints:off",
  "--hint:XDeclaredButNotUsed:off",
  "--hint:Name:off",
  "--hint:DuplicateModuleImport:off",
  "-d:useMalloc",
  "-d:withReinstantiation",
  "-d:genFilePath:" & quotes(config.genFilePath),
  "-d:pluginDir:" & quotes(config.pluginDir),

]


let targetSwitches* =
  case config.targetConfiguration:
    of Debug, Development:
      var ts = @["--opt:none"]
      if withDebug:# and not defined(windows):
        ts &= @["--stacktrace:on"]
        # if not defined(windows):
        # ts &= @["--debugger:native"]
        ts &= @["--linedir:on"]#, "--debugInfo"]
        
      ts
    of Shipping: @["--danger"]
      

let hostPlatformSwitches* = getPlatformSwitches(false, false)
let pluginPlatformSwitches* = getPlatformSwitches(withPch, withDebug) 
