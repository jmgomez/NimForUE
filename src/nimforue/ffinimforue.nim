

include unreal/prelude
import macros/[ffi]
import std/[options, strformat]

const genFilePath* {.strdefine.} : string = ""


proc printAllClassAndProps*(prefix:string, package:UPackagePtr) =
    let classes = getAllObjectsFromPackage[UNimClassBase](package)

    UE_Error prefix & " len classes: " & $classes.len()
    for c in classes:
        UE_Warn " Class " & c.getName()
        for p in getFPropsFromUStruct(c):
            UE_Log "Prop " & p.getName()

proc onNimForUELoaded(n:int32) : pointer {.ffi:genFilePath} = 
    UE_Log(fmt "Nim loaded for {n} times")

  
    try:
    
  
        let nimPackage = tryGetPackageByName("Nim").get(createNimPackage("Nim"))
        UE_Log &"Nim Package {nimPackage}"
        let isFirstLoad = n == 0
        let nimHotReload = emitUStructsForPackage(isFirstLoad, nimPackage)
        
    
        # printAllClassAndProps("POST", pkg)

        # scratchpadEditor()
        return nimHotReload
    except Exception as e:
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()
    # scratchpadEditor()



#called right before it is unloaded
#called from the host library

#returns a TMap<UClassPtr, UClassPtr> with the classes that needs to be hotreloaded
proc onNimForUEUnloaded() : void {.ffi:genFilePath}  = 
    UE_Log("Nim for UE unloaded")
   

    discard
