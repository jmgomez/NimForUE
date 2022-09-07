include ../../definitions
import ../containers/unrealstring




#TODO now vectors are defined as TVector[T] and there are FVector3f (this) and FVector3d 
#Not sure if it will be better to just do an alias 

type FColor*{.importcpp, bycopy } = object
type FLinearColor*{.importcpp, bycopy } = object
type FRotator*{.importcpp, bycopy } = object
type FVector2D*{.importcpp, bycopy } = object
type FVector4*{.importcpp, bycopy } = object
type FVector*{.importcpp, bycopy } = object
  x*: float32
  y*: float32
  z*: float32

proc makeFVector*(x, y, z: cfloat): FVector {.importcpp:"FVector(@)", constructor.}

proc toString*(v: FVector): FString {.importcpp:"#.ToString()"}

# {.push header:"Math/Vector.h".} #Seems like variables cant be imported without the header pragma? Commented it out for PCH, worth case scenario they can be manually recreated
# var zeroVector* {.importcpp: "FVector::ZeroVector".}: FVector
# var upVector* {.importcpp: "FVector::UpVector".}: FVector
# var forwardVector* {.importcpp: "FVector::ForwardVector".}: FVector
# var rightVector* {.importcpp: "FVector::RightVector".}: FVector
# {.pop.}
func `+`*(a,b: FVector): FVector {.importcpp:"# + #", noSideEffect.}
func `==`*(a,b: FVector): bool {.importcpp:"# == #", noSideEffect.}

