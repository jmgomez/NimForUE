include unrealprelude
 
import ../../unreal/bindings/imported/gameplayabilities/[abilities, gameplayabilities, enums]
export abilities, gameplayabilities, enums

type 
  IAbilitySystemInterface* {.importcpp.} = object
  IAbilitySystemInterfacePtr* = ptr IAbilitySystemInterface

proc getAbilitySystemGlobals*() : UAbilitySystemGlobals {.importcpp: "UAbilitySystemGlobals::Get()".}
proc initGlobalData*(globals:UAbilitySystemGlobals) {.importcpp: "#.InitGlobalData()".}
proc getBaseValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetBaseValue()".}
proc setBaseValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetBaseValue(#)".}
proc getCurrentValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetCurrentValue()".}
proc setCurrentValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetCurrentValue(#)".}
proc makeFGameplayAttributeData*(defaultValue: float32) : FGameplayAttributeData {.importcpp: "FGameplayAttributeData(#)", constructor.}

