import ../typegen/ueemit
import ../unreal/nimforue/[nimforuebindings, nimforue]
import ../unreal/coreuobject/[uobject, coreuobject, package, unrealtype, templates/subclassof, tsoftobjectptr, 
    nametypes, scriptdelegates, uobjectglobals, metadata]
import ../unreal/core/containers/[unrealstring, array, map, set]
import ../unreal/core/math/[vector]
import ../unreal/core/ftext
import ../unreal/core/[enginetypes, delegates]
import ../unreal/runtime/[assetregistry]


import ../utils/[utils, ueutils]

import engine

when not defined(getUEEmitter):
    proc getUEEmitter() : UEEmitter {.cdecl, dynlib, exportc.} =   ueEmitter
