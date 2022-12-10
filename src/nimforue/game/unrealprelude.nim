import ../typegen/[ueemit, emitter]
import ../unreal/nimforue/[nimforuebindings, nimforue]
import ../unreal/coreuobject/[uobject, coreuobject, package, unrealtype,tsoftobjectptr, 
    nametypes, scriptdelegates, uobjectglobals, metadata]
import ../unreal/core/containers/[unrealstring, array, map, set]
import ../unreal/core/math/[vector]
import ../unreal/core/ftext
import ../unreal/core/[enginetypes, delegates]
import ../unreal/runtime/[assetregistry]

import ../utils/[utils, ueutils]
import extras
import engine

when not defined(getUEEmitter):
    #This function is requested by the plugin when it load this dll
    #The UEEmitter should also have the package name where it supposed to push
    proc getUEEmitter() : UEEmitter {.cdecl, dynlib, exportc.} =   ueEmitter
