include ../../definitions
import ../containers/unrealstring




#TODO now vectors are defined as TVector[T] and there are FVector3f (this) and FVector3d 
#Not sure if it will be better to just do an alias 

#TODO need to handle float64 vs float32 not sure how ue exactly does it
type FVector*{.importcpp, inheritable,pure, bycopy .} = object
  x* {.importcpp:"X".} : float32
  y* {.importcpp:"Y".} : float32
  z* {.importcpp:"Z".} : float32




proc makeFVector*(x, y, z: float32): FVector {.importcpp:"FVector(@)", constructor.}

proc toString*(v: FVector): FString {.importcpp:"#.ToString()"}

# {.push header:"Math/Vector.h".} #Seems like variables cant be imported without the header pragma? Commented it out for PCH, worth case scenario they can be manually recreated
# var zeroVector* {.importcpp: "FVector::ZeroVector".}: FVector
# var upVector* {.importcpp: "FVector::UpVector".}: FVector
# var forwardVector* {.importcpp: "FVector::ForwardVector".}: FVector
# var rightVector* {.importcpp: "FVector::RightVector".}: FVector
# {.pop.}


func `+`*(a,b: FVector): FVector {.importcpp:"# + #", noSideEffect.}
func `-`*(a,b: FVector): FVector {.importcpp:"# - #", noSideEffect.}
func `*`*(a : SomeFloat | SomeNumber, b: FVector): FVector {.importcpp:"# * #", noSideEffect.}
func `*`*(a : FVector, b: SomeNumber | SomeFloat): FVector {.importcpp:"# * #", noSideEffect.}
func `==`*(a,b: FVector): bool {.importcpp:"# == #", noSideEffect.}



type 
  FVector_NetQuantize*{.importcpp, inheritable } = object of FVector #Better in net related stuff
  FVector_NetQuantizeNormal*{.importcpp, inheritable } = object of FVector 
  FVector_NetQuantize100*{.importcpp, inheritable } = object of FVector 
  FVector_NetQuantize10*{.importcpp, inheritable } = object of FVector 


# converter toVector*(v: FVector_NetQuantize | FVector_NetQuantizeNormal): FVector = FVector(x: v.x, y: v.y, z: v.z)