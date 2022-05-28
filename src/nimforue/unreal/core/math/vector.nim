import ../containers/unrealstring


{.push header:"Math/Vector.h" .}

#TODO now vectors are defined as TVector[T] and there are FVector3f (this) and FVector3d 
#Not sure if it will be better to just do an alias 

type FVector*{.importcpp: "FVector", bycopy } = object
  x*: float32
  y*: float32
  z*: float32

proc makeFVector*(x, y, z: cfloat): FVector {.importcpp:"FVector(@)", constructor.}

proc toString*(v: FVector): FString {.importcpp:"#.ToString()"}


var zeroVector* {.importc: "FVector::ZeroVector".}: FVector
var upVector* {.importc: "FVector::UpVector".}: FVector
var forwardVector* {.importc: "FVector::ForwardVector".}: FVector
var rightVector* {.importc: "FVector::RightVector".}: FVector

func `+`*(a,b: FVector): FVector {.importcpp:"# + #", noSideEffect.}

{.pop.}