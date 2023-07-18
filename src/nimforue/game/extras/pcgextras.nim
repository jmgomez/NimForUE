include unrealprelude
import pcg
export pcg
#TODO Review valid T and check them at compile time. 
type 
  IPCGElement* {.importcpp.} = object
  FSimplePCGElement* {.importcpp, inheritable.} = object
  FPCGMetadataAttributeBase* {.importcpp.} = object
  FPCGMetadataAttributeBasePtr* = ptr FPCGMetadataAttributeBase

  FPCGMetadataAttribute*[T] {.importcpp.} = object
  FPCGMetadataAttributePtr*[T] = ptr FPCGMetadataAttribute[T]
  # FPCGContext* {.inheritable, pure, importcpp .} = object #TODO manually bind it and remove it from the general types
  #   inputData* {.importcpp:"InputData".} : FPCGDataCollection
  #   outputData* {.importcpp:"OutputData".} : FPCGDataCollection   
  #   # TWeakObjectPtr<UPCGComponent> SourceComponent #TODO Need to bind TWeakObjectPtr first
  #   node {.importcpp:"Node".} : UPCGNodePtr #node is const so we expose an accesor to avoid cpp annoying around



  FPCGContextPtr* = ptr FPCGContext
  FPCGElementPtr* = TSharedPtr[FSimplePCGElement] #in reality this is typedef TSharedPtr<IPCGElement, ESPMode::ThreadSafe> FPCGElementPtr; maybe we can just get rid of it and use TSharedPointer directly?

proc inputData*(self: FPCGContextPtr): FPCGDataCollection {.importcpp: "(#->InputData)".}
proc `inputData=`*(self: FPCGContextPtr, data: FPCGDataCollection) {.importcpp: "(#->InputData = #)".}
proc outputData*(self: FPCGContextPtr): FPCGDataCollection {.importcpp: "(#->OutputData)".}
proc `outputData=`*(self: FPCGContextPtr, data: FPCGDataCollection) {.importcpp: "(#->OutputData = #)".}

proc node*(self: FPCGContextPtr): UPCGNodePtr {.importcpp: "const_cast<'0>(#->Node)".}
proc sourceComponent*(self: FPCGContextPtr): UPCGComponentPtr {.importcpp: "(#->SourceComponent.Get())".}


proc getInputSettings*[T](self: FPCGContextPtr): ptr T {.importcpp: "#->GetInputSettings<'*0>()".}

#notice they dont share the base type but they should be comptabile
converter toUPCGData*(data:ptr UPCGPointData) : ptr UPCGData = ueCast[UPCGData](data)



func getGraph*(self:UPCGComponentPtr) : UPCGGraphPtr {.importcpp:"#->GetGraph()".}
func getNodes*(self:UPCGGraphPtr) : var TArray[UPCGNodePtr] {.importcpp:"#->GetNodes()".}
# proc forceNotificationForEditor*(self:UPCGGraphPtr) {.importcpp:"#->ForceNotificationForEditor()".}
proc notifyGraphChanged*(self:UPCGSubsystemPtr) {.importcpp: "#->NotifyGraphChanged()".}


proc metadata*(data:UPCGPointDataPtr): ptr UPCGMetadata {.importcpp: "(#->Metadata)".}
proc `metadata=`*(data:UPCGPointDataPtr, metadata: ptr UPCGMetadata) {.importcpp: "(#->Metadata = #)".}

proc getMutablePoints*(data:UPCGPointDataPtr): var TArray[FPCGPoint] {.importcpp: "(#->GetMutablePoints())".}

type PCGMetadataEntryKey* {.importcpp: "#".} = distinct int
proc isValid*(key: PCGMetadataEntryKey): bool {.importcpp: "(# > 0)".}

proc getMutableAttribute*[T](metadata: UPCGMetadataPtr, name:FName) : FPCGMetadataAttributePtr[T]  {.importcpp: "static_cast<'0>(#->GetMutableAttribute(@))".}
proc initializeOnSet*(metadata: UPCGMetadataPtr, key:PCGMetadataEntryKey)  {.importcpp: "#->InitializeOnSet(#)".}
proc setValue*[T](metadata: FPCGMetadataAttributePtr[T], key: PCGMetadataEntryKey, value: T) {.importcpp: "#->SetValue(@)".}


proc setAttribute*[T](point: var FPCGPoint, metadata: UPCGMetadataPtr, attributeName : FName, value : T) {.inline.} = 
  when T is int8 | int16 | int32 | uint | uint8 | uint16 | uint32:
    point.setInteger32Attribute(metadata, attributeName, value.int32)
  elif T is int | int64 | uint64:
    point.setInteger64Attribute(metadata, attributeName, value.int)
  elif T is float32:
    point.setFloat32Attribute(metadata, attributeName, value.float32)
  elif T is float64:
    point.setDoubleAttribute(metadata, attributeName, value.float)
  elif T is bool:
    point.setBoolAttribute(metadata, attributeName, value)  
  elif T is FString | string:
    point.setStringAttribute(metadata, attributeName, value)
  elif T is FQuat:
    point.setQuatAttribute(metadata, attributeName, value)
  elif T is FVector:
    point.setVectorAttribute(metadata, attributeName, value)
  elif T is FVector2D:
    point.setVector2DAttribute(metadata, attributeName, value)  
  elif T is FRotator:
    point.setRotatorAttribute(metadata, attributeName, value)     
  elif T is FTransform:
    point.setTransformAttribute(metadata, attributeName, value)  
  else:
    {.error: "Unsupported type".}

proc getAttribute*[T](point : FPCGPoint, metadata: UPCGMetadataPtr, attributeName : FName): T {.inline.} = 
  var point = point
  when T is int8 | int16 | int32 | uint | uint8 | uint16 | uint32:
    point.getInteger32Attribute(metadata, attributeName)
  elif T is int | int64 | uint64:
    point.getInteger64Attribute(metadata, attributeName)
  elif T is float32:
    point.getFloat32Attribute(metadata, attributeName)
  elif T is float64:
    point.getDoubleAttribute(metadata, attributeName)
  elif T is bool:
    point.getBooleanAttribute(metadata, attributeName)  
  elif T is FString | string:
    point.getStringAttribute(metadata, attributeName)
  elif T is FQuat:
    point.getQuatAttribute(metadata, attributeName)
  elif T is FVector:
    point.getVectorAttribute(metadata, attributeName)
  elif T is FVector2D:
    point.getVector2DAttribute(metadata, attributeName)  
  elif T is FRotator:
    point.getRotatorAttribute(metadata, attributeName)     
  elif T is FTransform:
    point.getTransformAttribute(metadata, attributeName)  
  else:
    {.error: "Unsupported type".}


#	static void SetStringAttribute(UPARAM(ref) FPCGPoint& Point, UPCGMetadata* Metadata, FName AttributeName, const FString& Value);
proc setStringAttribute*(point: var FPCGPoint, metadata: UPCGMetadataPtr, attributeName : FName, value : FString) {.importcpp: "UPCGMetadataAccessorHelpers::SetStringAttribute(@)".}

#this function should be autobound. For reason it isnt
proc initializeFromData*(self:UPCGPointDataPtr, data:UPCGPointDataPtr) {.importcpp: "#->InitializeFromData(#)".}



#point helpers

proc pos*(point: FPCGPoint): FVector = point.transform.getLocation()
proc `pos=`*(point: FPCGPoint, value:FVector) =
  point.transform.setLocation(value)


