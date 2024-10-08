include unrealprelude

when WithEditor:
  import ../../unreal/bindings/imported/gameplayabilities/[abilities, gameplayabilities, enums]
else:
  import ../../unreal/bindings/exported/gameplayabilities/[abilities, gameplayabilities, enums]

export abilities, gameplayabilities, enums

type 
  IAbilitySystemInterface* {.importcpp.} = object
  IAbilitySystemInterfacePtr* = ptr IAbilitySystemInterface
  FOnAttributeChangeData* {.importcpp} = object
    attribute* {.importcpp: "Attribute"}: FGameplayAttribute
    newValue* {.importcpp: "NewValue"}: float32
    oldValue* {.importcpp: "OldValue"}: float32
    #geModData* {.importcpp: "GEModData"}: FGameplayEffectModCallbackDataPtr # const FGameplayEffectModCallbackData*

  FOnGameplayAttributeValueChange* = TMulticastDelegateOneParam[FOnAttributeChangeData]

proc getAbilitySystemComponent*(asi: IAbilitySystemInterfacePtr) : UAbilitySystemComponentPtr {.importcpp: "#.GetAbilitySystemComponent()".}
proc getAbilitySystemGlobals*() : UAbilitySystemGlobals {.importcpp: "UAbilitySystemGlobals::Get()".}
proc initGlobalData*(globals:UAbilitySystemGlobals) {.importcpp: "#.InitGlobalData()".}
proc getBaseValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetBaseValue()".}
proc setBaseValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetBaseValue(#)".}
proc getCurrentValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetCurrentValue()".}
proc setCurrentValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetCurrentValue(#)".}
proc makeFGameplayAttributeData*(defaultValue: float32) : FGameplayAttributeData {.importcpp: "FGameplayAttributeData(#)", constructor.}

proc makeFGameplayAttribute*(prop: FPropertyPtr): FGameplayAttribute {.importcpp: "FGameplayAttribute(#)", constructor.}
proc getOwningAbilitySystemComponent*(attributeSet: UAttributeSetPtr): UAbilitySystemComponentPtr {.importcpp: "#->GetOwningAbilitySystemComponent()".}
proc getOwningAbilitySystemComponentChecked*(attributeSet: UAttributeSetPtr): UAbilitySystemComponentPtr {.importcpp: "#->GetOwningAbilitySystemComponentChecked()".}

proc `==`*(a, b: FGameplayAttribute): bool {.importcpp: "(#==#)".}

proc setNumericAttributeBase*(asc: UAbilitySystemComponentPtr, attribute: FGameplayAttribute, value: float32) {.importcpp: "#->SetNumericAttributeBase(@)".}
proc setBaseAttributeValueFromReplication*(asc: UAbilitySystemComponentPtr, attribute: FGameplayAttribute, newValue, oldValue: FGameplayAttributeData ) {.importcpp: "#->SetBaseAttributeValueFromReplication(@)".}
proc setReplicationMode*(asc: UAbilitySystemComponentPtr, newReplicationMode: EGameplayEffectReplicationMode) {.importcpp:"#->SetReplicationMode((EGameplayEffectReplicationMode)#)".}
proc getGameplayAttributeValueChangeDelegate*(asc: UAbilitySystemComponentPtr, attribute: FGameplayAttribute): var FOnGameplayAttributeValueChange {.importcpp:"#->GetGameplayAttributeValueChangeDelegate(#)".}


proc initAbilityActorInfo*(asc:UAbilitySystemComponentPtr, actor: AActorPtr, avatar: AActorPtr) {.importcpp: "#->InitAbilityActorInfo(#, #)".}
proc getSpawnedAttributesMutable*(asc:UAbilitySystemComponentPtr): var TArray[UAttributeSetPtr] {.importcpp: "#->GetSpawnedAttributes_Mutable()".}

#	virtual bool CommitAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, OUT FGameplayTagContainer* OptionalRelevantTags = nullptr);
proc commitAbility*(ability: UGameplayAbilityPtr, handle: FGameplayAbilitySpecHandle, actorInfo: ptr FGameplayAbilityActorInfo, activationInfo: FGameplayAbilityActivationInfo): bool {.importcpp: "#->CommitAbility(@)".}

proc add*(handle: FGameplayAbilityTargetDataHandle, data: ptr FGameplayAbilityTargetData) {.importcpp: "#.Add(#)".}
proc get*(handle: FGameplayAbilityTargetDataHandle, index: int): ptr FGameplayAbilityTargetData {.importcpp: "#.Get(#)".}
proc netSerialize*(predKey: FPredictionKey, ar: var FArchive, map: UPackageMapPtr, bOutSuccess: var bool) {.importcpp:"#.NetSerialize(@)".}

proc isActive*(abilitySpec: ptr FGameplayAbilitySpec): bool {.importcpp: "#->IsActive()".}
#ASC
#FGameplayAbilitySpec* UAbilitySystemComponent::FindAbilitySpecFromClass(TSubclassOf<UGameplayAbility> InAbilityClass) const
proc findAbilitySpecFromClass*(asc: UAbilitySystemComponentPtr, inAbilityCls: TSubclassOf[UGameplayAbility]): ptr FGameplayAbilitySpec {.importcpp:"#->FindAbilitySpecFromClass(@)".}


