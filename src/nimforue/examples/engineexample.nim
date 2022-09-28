include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore]
# import ../unreal/bindings/exported/[slate, slatecore]
# import ../unreal/bindings/exported/nimforue
import ../typegen/[uemeta]
import std/random


  
# type
#   FSlateBrush*  = object
#   # FSlateBrush* {.importcpp, header:"Styling/SlateBrush.h".} = object
#     # bIsDynamicallyLoaded*: uint8
#     # imageType*: ESlateBrushImageType
#     # mirroring*: ESlateBrushMirrorType
#     # tiling*: ESlateBrushTileType
#     # drawAs*: ESlateBrushDrawType
#     # uVRegion*: FBox2f
#     # resourceName*: FName
#     # resourceObject*: TObjectPtr[UObject]
#     # outlineSettings*: FSlateBrushOutlineSettings
#     # tintColor*: FSlateColor
#     # margin*: FMargin
#     ImageSize*: FVector2D

#[
  The problem seems to be the inner UOBjects not being init. Maybe I can replicate that in NimForUEBindings?
  If it can be replicated, we can see the default value from them?
]#

# type
#   FTextBlockStyle*  = object
#     strikeBrush*: FSlateBrush


uStruct FMyUStructDemoTest:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
        propString: FString
        propInt: int32
        propInt64: int
        propInt642: int64

# uClass AObjectEngineExample of AActor:
#   (BlueprintType)
#   uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
#     stringProp : FString
#     intProp : int32
#     another : FTextBlockStyle
#     # intProp2 : int32

#   ufuncs(CallInEditor):
#     proc testTextBlockStyle() = 
#       var testStr = self.another
#       testStr.shadowOffset = FVector2D(x:100, y:12)
#       self.another = FTextBlockStyle()
#       UE_Log "Slate struct"
#       UE_Log $self.another 
#       UE_Log $self.another.shadowOffset

proc setResourceObject(slateBrush: ptr FSlateBrush,inResourceObject: UObjectPtr) {.importcpp:"(reinterpret_cast<FSlateBrush*>(#))->SetResourceObject(#)",  header:"Styling/SlateBrush.h".}


const testActorUEType = UEType(name: "ATestActor", parent: "AActor", kind: uetClass)
              
genType(testActorUEType)

uClass UObjectTestFake of UObject:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    
type 
  UPaperSprite* = object of UObject
  UPaperSpritePtr* = ptr UPaperSprite

uClass AObjectEngineExampleSlateBrush of ATestActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    another : FSlateBrush
    another2 : FVolumeControlStyle
    scriptStruct : UObjectPtr #FObjectProperty -> 
    whatever : FString
    texture : UTexturePtr
    sprite : UPaperSpritePtr
    headerRowStyle : FHeaderRowStyle 
    test : FMyUStructDemoTest
    sc : FSlateColor
    c : FColor
    # intProp2 : int32
  ufuncs():
    proc tick() = 
      let str = getUTypeByName[UScriptStruct]("SlateBrush")
      UE_Log $str
      self.scriptStruct = (str)

  ufuncs(CallInEditor):
    proc setStringProp() = 
      if self.test.propString == "":
        self.test = FMyUStructDemoTest(propString:"asdsad", propInt:1)
      else:
        self.test = FMyUStructDemoTest(propString:"test" &  self.test.propString, propInt: 1 + self.test.propInt)
      
      if self.c.r == 0:
        self.c = FColor(r:40, g:0, b:0, a:255)
      else:
        self.c = FColor(r:self.c.r+40, g:0, b:0, a:255) 
      
      if self.sc.specifiedColor.r == 0.float32:
        self.sc = FSlateColor(specifiedColor:FLinearColor(r:0.1.float32, g:0.float32, b:0.float32, a:1.float32))
      else:
        self.sc = FSlateColor(specifiedColor:FLinearColor(r:0.1.float32 + self.sc.specifiedColor.r, g:0.float32, b:0.float32, a:1.float32))

      UE_Log $self.sc
     
    proc testSlateBrush() = 
      UE_Log $self.test
      # let textObj = ueCast[UObject](self.scriptStruct)
      var brush =  FSlateBrush()
      # setResourceObject(brush.addr, self.sprite)
      # self.another = FSlateBrush(resourceObject:newUObject[UObjectTestFake]())
      UE_Log "Slate brush"
      # UE_Log $self.another 

    proc testFHeaderRowStyle() = 
      self.test = FMyUStructDemoTest(propString:"asdsad", propInt:1)
      # self.test.propString = "hola" & self.test.propString

      var header = FHeaderRowStyle()
      header.splitterHandleSize = rand(100).float32
      # self.headerRowStyle = header
      UE_Log "Slate brush"
      # UE_Log $self.headerRowStyle
      UE_Log $header
      UE_Log $header.splitterHandleSize


    proc showSlateBrushProps() = 
      let str = getUTypeByName[UScriptStruct]("SlateBrush")
      UE_Log $str

      UE_Log $str.structFlags
      if (STRUCT_AddStructReferencedObjects.uint32 and str.structFlags.uint32) != 0:
        UE_Log "STRUCT_AddStructReferencedObjects"
      if (STRUCT_HasInstancedReference.uint32 and str.structFlags.uint32) != 0:
        UE_Log "STRUCT_HasInstancedReference"
      if (STRUCT_IdenticalNative.uint32 and str.structFlags.uint32) != 0:
        UE_Log "STRUCT_IdenticalNative"
      
      let val = str.structFlags.uint32
      UE_Log $val
      UE_Log $STRUCT_HasInstancedReference.uint32

# uStruct FMyUStructDemoTestObject:
#     (BlueprintType)
#     uprop(EditAnywhere, BlueprintReadWrite):
#       bIsDynamicallyLoaded: bool
#       imageType: ESlateBrushImageType
#       mirroring: ESlateBrushMirrorType
#       tiling: ESlateBrushTileType
#       drawAs: ESlateBrushDrawType
#       uVRegion: FBox2f
#       resourceName: FName
#       resourceObject: TObjectPtr[UObject]
#       outlineSettings: FSlateBrushOutlineSettings
#       tintColor: FSlateColor
#       margin: FMargin
#       imageSize: FVector2D
       

#[
    overflowPolicy*: ETextOverflowPolicy
    transformPolicy*: ETextTransformPolicy
    underlineBrush*: FSlateBrush
    strikeBrush*: FSlateBrushsp[l
    highlightShape*: FSlateBrush
    highlightColor*: FSlateColor
    selectedBackgroundColor*: FSlateColor
    shadowColorAndOpacity*: FLinearColor
    shadowOffset*: FVector2D
    colorAndOpacity*: FSlateColor
    font*: FSlateFontInfo
]#

# uClass AObjectEngineExampleTextBlockSplit of AActor:
#   (BlueprintType)
#   uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
#     stringProp : FString
#     intProp : int32
#     another : FMyUStructDemoTestObject
#     another2 : FSlateBrush
#     # intProp2 : int32

#   ufuncs(CallInEditor):
#     proc testFMyUStructDemoTestObject() = 
#       self.another = FMyUStructDemoTestObject()
#       UE_Log $self.another 

#     proc testFBrush() = 
#       self.another2 = FSlateBrush()
#       UE_Log $self.another2 


# uClass AObjectEngineExampleColor of AActor:
#   (BlueprintType)
#   uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
#     stringProp : FString
#     intProp : int32
#     another : FColor
#     another2 : FMyUStructDemoTest
#     another3 : FSlateColor
#     another4 : FTestStructToBind
#     another5 : FTestStructToBindWithObject
#     another6 : FTestStructToBindChild
#     # intProp2 : int32

#   ufuncs(CallInEditor):
#     proc testFColor() = 
      
#       let testStr = FColor()
#       self.another = testStr
#       UE_Log "color"
#       UE_Log $self.another 

#     proc testFCustomStruct() = 
#       let testStr = FMyUStructDemoTest()
#       self.another2 = testStr
#       UE_Log "FMyUStructDemoTest"
#       UE_Log $self.another2 


#     proc testFSlateColor() = 
#       let testStr = FSlateColor()
#       self.another3 = testStr
#       UE_Log "FSlateColor"
#       UE_Log $self.another3

#     proc testFTestStructToBind() = 
#         let testStr = FTestStructToBind()
#         self.another4 = testStr
#         UE_Log $self.another4

#     proc testFTestStructToBindWithObject() = 
#         let testStr = FTestStructToBindWithObject()
#         self.another5 = testStr
#         UE_Log $self.another5

#     proc testFTestStructToBindChild() = 
#         let testStr = FTestStructToBindChild()
#         self.another6 = testStr
#         UE_Log $self.another5


      