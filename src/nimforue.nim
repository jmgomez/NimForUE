import nimforue/[ffinimforue]
import nimforue/macros/ffi

# const genFilePath* {.strdefine.} : string = ""

# proc getNextLibraryName*() : cstring {. cdecl, exportc, dynlib, ffi:genFilePath.} = 
#   "/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/MacOs/Plugins/NimForUE/Binaries/nim/ue/libNimForUE-1.dylib".cstring

# proc helloWorld2*() : void {. cdecl, exportc, dynlib, ffi:genFilePath.} = 
#     echo "Hello 2"

