    
type
  ELifetimeCondition* {.size: sizeof(uint8), pure, importcpp.} = enum
    COND_None, COND_InitialOnly, COND_OwnerOnly, COND_SkipOwner,
    COND_SimulatedOnly, COND_AutonomousOnly, COND_SimulatedOrPhysics,
    COND_InitialOrOwner, COND_Custom, COND_ReplayOrOwner, COND_ReplayOnly,
    COND_SimulatedOnlyNoReplay, COND_SimulatedOrPhysicsNoReplay,
    COND_SkipReplay, COND_Never, COND_Max

  ELifetimeRepNotifyCondition* {.size: sizeof(uint8), pure, importcpp .} = enum
    REPNOTIFY_OnChanged,  # Only call the property's RepNotify function if it changes from the local value
    REPNOTIFY_Always,  #Always Call the property's RepNotify function when it is received from the server

  FDoRepLifetimeParams* {.importcpp.} = object 
    condition* {.importcpp:"Condition".}: ELifetimeCondition
    repNotifyCondition* {.importcpp:"RepNotifyCondition".}: ELifetimeRepNotifyCondition
    bIsPushBased*: bool