import std/[sequtils, options, sugar, strutils, strformat, typetraits]


type
  FieldKind* = enum
    Int, Float, String, Struct,# Seq, Object
  
  RuntimeField* = object
    case kind*: FieldKind
    of Int:
      intVal*: int
    of Float:
      floatVal*: float
    of String:
      stringVal*: string
    of Struct:
      structVal*: RuntimeStruct
    
  RuntimeStruct* = seq[(string, RuntimeField)]
 
  UEFunc* = object #Light metadata we could ue UFunc but we dont want to pull all those types into the vm
    name* : string
    className* : string

   
  UECall* = object
    fn* : UEFunc 
    self* : int
    value* : RuntimeField #On uebind [name] = value #let's just do runtimeFields only for now and then we can put an object in here, although a field may contain an object

# func toRuntimeField*[T](value : T) : RuntimeField 
func add*(rtField : var RuntimeField, name : string, value : RuntimeField) = 
  case rtField.kind:
  of Struct:
    rtField.structVal.add((name, value))
  else:
    raise newException(ValueError, "rtField is not a struct")

func getInt*(rtField : RuntimeField) : int = 
  case rtField.kind:
  of Int:
    return rtField.intVal
  else:
    raise newException(ValueError, "rtField is not an int")

func getFloat*(rtField : RuntimeField) : float =
  case rtField.kind:
  of Float:
    return rtField.floatVal
  else:
    raise newException(ValueError, "rtField is not a float")

func getStr*(rtField : RuntimeField) : string =
  case rtField.kind:
  of String:
    return rtField.stringVal
  else:
    raise newException(ValueError, "rtField is not a string")

func getStruct*(rtField : RuntimeField) : RuntimeStruct =
  case rtField.kind:
  of Struct:
    return rtField.structVal
  else:
    raise newException(ValueError, "rtField is not a struct")

func setInt*(rtField : var RuntimeField, value : int) = 
  case rtField.kind:
  of Int:
    rtField.intVal = value
  else:
    raise newException(ValueError, "rtField is not an int")

func setFloat*(rtField : var RuntimeField, value : float) =
  case rtField.kind:
  of Float:
    rtField.floatVal = value
  else:
    raise newException(ValueError, "rtField is not a float")

func setStr*(rtField : var RuntimeField, value : string) =
  case rtField.kind:
  of String:
    rtField.stringVal = value
  else:
    raise newException(ValueError, "rtField is not a string")
func setStruct*(rtField : var RuntimeField, value : RuntimeStruct) =
  case rtField.kind:
  of Struct:
    rtField.structVal = value
  else:
    raise newException(ValueError, "rtField is not a struct")

func `[]`*(rtField : RuntimeField, name : string) : RuntimeField = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name:
        return value
    raise newException(ValueError, "Field " & name & " not found in struct")
  else:
    raise newException(ValueError, "rtField is not a struct")



func contains*(rtField : RuntimeField, name : string) : bool = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name:
        return true
    return false
  else:
    raise newException(ValueError, "rtField is not a struct")



# func toRuntimeField*(value : JsonNode) : RuntimeField = 
#   case value.kind:
#   of JInt:
#     result.kind = Int
#     result.intVal = value.getInt()
#   of JFloat:
#     result.kind = Float
#     result.floatVal = value.getFloat()
#   of JString:
#     result.kind = String
#     result.stringVal = value.getStr()
#   of JObject:
#     result.kind = Struct
#     for key, val in value.fields:
#       result.structVal.add((key, toRuntimeField(val)))
#   else:
#     raise newException(ValueError, "Unsupported json type for RuntimeField ")

# func toRuntimeFieldHook*[T](value : T) : RuntimeField = toRuntimeField*[T](value : T)

proc runtimeFieldTo*[T](rtField : RuntimeField) : T = 
  when compiles(fromRuntimeFieldHook(rtField)): 
    return fromRuntimeFieldHook(rtField)
  else:
    const typeName = typeof(T).name
    case rtField.kind:
    of Int:
      when T is int | int8 | int16 | int32 | int64 | uint | uint8 | uint16 | uint32 | uint64 :
        return cast[T](rtField.intVal)
    of Float:
      when T is float | float32 | float64:
        return cast[T](rtField.floatVal)
    of String:
      when T is string:
        return (rtField.stringVal)
      
    of Struct:
      #TODO only vectors for now
      raise newException(ValueError, "Unsupported type for RuntimeField " & typeName)
     
proc runtimeFieldTo*(rtField : RuntimeField, T : typedesc) : T = runtimeFieldTo[T](rtField)

proc toRuntimeField*[T](value : T) : RuntimeField = 
  when compiles(toRuntimeFieldHook(value)): 
    return toRuntimeFieldHook(value)
  else:
    const typeName = typeof(T).name
    when T is int | int8 | int16 | int32 | int64 | uint | uint8 | uint16 | uint32 | uint64 :
      result.kind = Int
      result.intVal = cast[int](value)
    elif T is float | float32 | float64:
      result.kind = Float
      result.floatVal = value
    elif T is string:
      result.kind = String
      result.stringVal = value
    elif T is (object | tuple):
      result.kind = Struct
      for name, val in fieldPairs(value):
        result.structVal.add((name, toRuntimeField(val)))
    else:
      when compiles(UE_Error ""):
        UE_Error &"Unsupported {typeName} type for RuntimeField "
      else:
        debugEcho "ERROR: Unsupported {typeName} type for RuntimeField"
      RuntimeField()
    # raise newException(ValueError, &"Unsupported {typename} type for RuntimeField ")
func initRuntimeField*[T](value : T) : RuntimeField = toRuntimeField(value)
