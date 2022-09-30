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


uClass AObjectEngineExample of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    another : FTextBlockStyle
    c: FSlateColor
    lc: FLinearColor

  ufuncs(CallInEditor):
    proc testTextBlockStyle() = 
      var testStr = self.another
      testStr.shadowOffset = FVector2D(x:100, y:12)
      self.another = FTextBlockStyle(shadowOffset: testStr.shadowOffset)
      UE_Log "Slate struct"
      UE_Log $self.another 
      UE_Log $self.another.shadowOffset
    
    proc testResetSlateColor() =
      self.c = FSlateColor(specifiedColor: FLinearColor(r: 0.1f, g:0.9f, b:0.8f, a: 1.0f))
    proc testSlateColor() =
      self.lc = FLinearColor(r: 0.5f, g: 0.6f, b:0.7f, a:1.0f)
      self.c = FSlateColor(specifiedColor: FLinearColor(r: self.c.specifiedColor.r + 0.1f, g:0.9f, b:0.8f, a: 1.0f))
    
    proc testUButtonWidgeStyle() =
      let style = newUObject[UButtonWidgetStyle]()
      UE_Log $style