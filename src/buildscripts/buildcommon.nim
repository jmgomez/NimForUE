import std / [json, strutils, terminal]

template quotes*(path: string): untyped =
  "\"" & path & "\""

type TargetPlatform* = enum
    Mac = "Mac"
    Win64 = "Win64"
    #TODO Fill the rest

type TargetConfiguration* = enum
    Debug = "Debug"
    Development = "Development"
    Shipping = "Shipping"
    #TODO Fill the rest

proc fromJsonHook*(self: var TargetPlatform, jsonNode:JsonNode) =
  self = parseEnum[TargetPlatform](jsonNode.getStr())

proc fromJsonHook*(self: var TargetConfiguration, jsonNode:JsonNode) =
  self = parseEnum[TargetConfiguration](jsonNode.getStr())

proc toJsonHook*(self:TargetPlatform) : JsonNode = newJString($self)
proc toJsonHook*(self:TargetConfiguration) : JsonNode = newJString($self)


type LogLevel* = enum 
  lgNone
  lgInfo
  lgDebug 
  lgWarning
  lgError

proc log*(msg:string, level=lgInfo) = 
  let color = case level 
    of lgNone: fgwhite
    of lgInfo: fgblue
    of lgDebug: fgmagenta
    of lgWarning: fgyellow
    of lgError: fgred

  styledEcho(color, msg, resetStyle)


func getFullLibName*(baseLibName: string): string  = 
  when defined macosx:
    return "lib" & baseLibName & ".dylib"
  elif defined windows:
    return  baseLibName & ".dll"
  #elif defined linux:
  #    return ""
  else:
    raise newException(Defect, "Uknown platform")