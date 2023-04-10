
include unrealprelude
import pcg
import extras/pcg

import std/[macros, enumerate]
import ../codegen/gencppclass


#pointdata functions:
class FNimPCGElement of FSimplePCGElement:  
  override:
    proc executeInternal(context: FPCGContextPtr):bool {.constcpp.} =
      #Assume first inputt
      if context.inputData.taggedData.len == 0:
        return true

      let pointData = ueCast[UPCGPointData](context.inputData.taggedData[0].data)       
      let outPointData = newUObject[UPCGPointData]()
      outPointData.initializeFromData(pointData)
      let points = pointData.getPoints() 
      var outPoints = points

      let metadata = outPointData.metadata
      metadata.createInteger32Attribute(n"TestInt32", 1, true)
      metadata.createInteger32Attribute(n"TestInt32Times2", 0, true)
      for idx, p in enumerate(outPoints.mitems):
        #change point properties like that
        p.color = FVector4(x:0.1)      
        p.transform.setScale3D(FVector(x: 0.5, y: 0.5, z: 0.5))
        p.setAttribute(metadata, n"TestAttrib", &"Test {idx}")
        p.setAttribute(metadata, n"TestInt32", idx.int32)
        #read
        let storedIdx = p.getAttribute[:int32](metadata, n"TestInt32")
        p.setAttribute(metadata, n"TestInt32Times2", storedIdx * 2.int32)

      
      outPointData.setPoints(outPoints)
      context.outputData.taggedData = makeTArray(FPCGTaggedData(data: outPointData))      
      true

uClass UPCGNimTestSettings of UPCGBaseSubgraphSettings:
  (Reinstance)
  uprops(EditAnywhere, BlueprintReadWrite):
    myProperty2 : FString

  override:
    proc getDefaultNodeName() : FName {.constcpp.} = n"NimTest"
    proc createElement() :  TSharedPtr[IPCGElement] {.constcpp.} =       
      makeShared[IPCGElement](cast[ptr IPCGElement](newCpp[FNimPCGElement]()))

