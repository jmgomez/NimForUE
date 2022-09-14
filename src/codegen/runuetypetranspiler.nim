


proc helloWorldFromCpp() : int {.importcpp, header:"UETypeTranspiled.h".}



type MyStructFromCpp {.importcpp, header:"UETypeTranspiled.h".} = object
  a, b, c : int32

proc makeMyStructFromCpp() : MyStructFromCpp {.importcpp: "'0()" .}


proc add10ToC(s: MyStructFromCpp) : MyStructFromCpp {.importcpp:"add10ToC(#)", header:"UETypeTranspiled.h".}



echo "hello form run uetypetranspiler dsads "
echo $helloWorldFromCpp()

echo "last thing "
var myStruct = makeMyStructFromCpp()
myStruct.c = 20

let another = myStruct.add10ToC()

echo "what"
echo $another
echo $another.c

