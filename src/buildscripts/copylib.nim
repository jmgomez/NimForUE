#This file exists due to the lack of support 
import std/[times, os, options, sugar, strutils, strscans, sequtils, random, algorithm]
import nimforueconfig
import ../nimforue/utils/utils

func getFullLibName(baseLibName:string) :string  = 
    when defined macosx:
        return "lib" & baseLibName & ".dylib"
    elif defined windows:
        return  baseLibName & ".dll"
    elif defined linux:
        return ""

proc getAllLibsFromPath*(libPath:string) : seq[string] =
    let libName = getFullLibName("nimforue")
    let libDir = libPath.replace(libName, "")
    let walkPattern = libDir / libName.replace(".", "*.")
    var libs = toSeq(walkFiles(walkPattern))
    let orderByRecent = (a, b : string) => cmp(getLastModificationTime(a), getLastModificationTime(b))
    libs.sort(orderByRecent, Descending)
    # echo "Found " & $len(libs)
    libs


proc getLastLibPath*(libPath:string): Option[string] =
        let libs = getAllLibsFromPath(libPath)
        if len(libs) == 0:
            return none[string]()
        some libs[0]


proc copyNimForUELibToUEDir*() = 
    var conf = getNimForUEConfig()
    let libDir = conf.pluginDir/"Binaries"/"nim"
    let libDirUE = libDir / "ue"   
    if not dirExists(libDirUE):
      createDir(libDirUE)
    
    let baseLibName = getFullLibName("nimforue")
    let nextFileName = getFullLibName("nimforue-1")

    let fileFullSrc = libDir/baseLibName
    #if there is no lib, we just keep the same name
    let libsCandidates = getAllLibsFromPath(libDirUE)
    let nLibs = len (libsCandidates)
    var fileFullDst  : string #This would be much better with pattern matching
    if nLibs == 0: #no libs, we just keep the same name
        fileFullDst = libDirUE/baseLibName
    elif nLibs == 1: #one lib, we create a new name
        fileFullDst = libDirUE/nextFileName
    elif nLibs == 2: #we just replace the oldest 
        fileFullDst = libsCandidates[^1]
    else:
        echo ""
    copyFile(fileFullSrc, fileFullDst)
    echo "Copied " & fileFullSrc & " to " & fileFullDst

proc copyNimForUELibToUEDirMacOs*() = 
    var conf = getNimForUEConfig()
    let libDir = conf.pluginDir/"Binaries"/"nim"
    let libDirUE = libDir / "ue"   
    if not dirExists(libDirUE):
      createDir(libDirUE)
    
    let libsCandidates = getAllLibsFromPath(libDirUE)
    proc extractNumber(filename:string): int = 
        var number : int = 0
        var ignore : string
        discard scanf(filename, "$*-$i.$*", ignore, number, ignore)
        number

    let nextLibNumber = if libsCandidates.any():
                            libsCandidates
                                .map(path=>path.split("/")[^1])
                                .map(extractNumber)
                                .max() + 1
                        else:
                            0
    

    let baseLibName = getFullLibName("nimforue")
    let nextFileName = getFullLibName("nimforue-" & $(nextLibNumber))

    let fileFullSrc = libDir/baseLibName
    
    for libPath in libsCandidates:
        #deletes previus used ones
        removeFile(libPath)
    
    let nLibs = len (libsCandidates)
    var fileFullDst  : string #This would be much better with pattern matching
    if nLibs == 0: #no libs, we just keep the same name
        fileFullDst = libDirUE/baseLibName
    else: #more than one lib, we create a new name
        fileFullDst = libDirUE/nextFileName
    
        echo ""
    copyFile(fileFullSrc, fileFullDst)
    echo "Copied " & fileFullSrc & " to " & fileFullDst

    
       


when isMainModule:
    echo "CopyLib script:"
    when defined macosx:
        copyNimForUELibToUEDirMacOs()
    elif defined windows:
        copyNimForUELibToUEDir()