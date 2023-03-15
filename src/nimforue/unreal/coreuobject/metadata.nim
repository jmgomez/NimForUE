import ../core/containers/unrealstring
import uobject


type
    UMetadata* {.importcpp.} = object of UObject
    UMetadataPtr* = ptr UMetadata




