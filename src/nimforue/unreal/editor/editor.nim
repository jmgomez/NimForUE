import ../core/delegates
import std/typetraits

type TMulticastDelegateOneParam*[T] {.importc:"TMulticastDelegate<void(bool)>", nodecl .} = object

type FOnPIEEvent* = TMulticastDelegateOneParam[bool]
# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}



var onBeginPIEEvent* {.importcpp:"(FEditorDelegates::BeginPIE)", nodecl.}  : FOnPIEEvent
var onEndPIEEvent* {.importcpp:"(FEditorDelegates::EndPIE)", nodecl.}  : FOnPIEEvent


#Notice:
  #1. Needs to be var, otherwise it will create a copy
  #2. The labmda needs to be c compatible func
  #3. The lambda needs to be captured 
  #4. Probably we will need to hardcode more values in here. But we will as we go, it will be easier to just expose a hook in the reflection helpers
proc addLambda*[T](del: var TMulticastDelegateOneParam[T], lambda : proc(b:T) {.cdecl.}) = 
  const typeName = typeof(T).name
  {.emit:[del, ".AddLambda([lambda](const " & typeName & " b){", lambda,"(b);});"].}
