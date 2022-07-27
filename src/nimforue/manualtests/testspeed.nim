include ../unreal/prelude


echo "hello 2"

uClass UTest of UObject:
    (BlueprintType)
    uprop(BlueprintReadWrite, EditAnywhere):
        test2 : FString

 
# let self = newUObject[UTest]() 


uFunctions():
    (self:UTestPtr)
    proc test() =  UE_Log "hello sdasd 15" & self.getName()
    proc test2() =  UE_Log "hello 5" & self.getName()
    proc test3() =  UE_Log "hello 5" & self.getName()
    proc te2test() =  UE_Log "hello 5" & self.getName()
    proc te2est() =  UE_Log "hello 5" & self.getName()
    proc te2es2t() =  UE_Log "hello 5" & self.getName()
    proc te1st() =  UE_Log "hello 5" & self.getName()
    proc teest() =  UE_Log "hello2 5" & self.getName()
    proc teest2() =  UE_Log "hel2lo 5" & self.getName()
    proc teest3() =  UE_Log "hello 15" & self.getName()
    proc tee2teest() =  UE_Log "hello 5" & self.getName()
    proc tee2est() =  UE_Log "hello 5" & self.getName()
    proc tee2es2t() =  UE_Log "hello 5" & self.getName()
    proc tee1st() =  UE_Log "hello 5" & self.getName()
    proc teeest() =  UE_Log "hello 5" & self.getName()
    proc teeest2() =  UE_Log "hello 5" & self.getName()
    proc teeest3() =  UE_Log "hello 5" & self.getName()
    proc teee2teeest() =  UE_Log "hello 5" & self.getName()
    proc teee2est() =  UE_Log "hello 5" & self.getName()
    proc teee2es2t() =  UE_Log "hello 5" & self.getName()
    proc teee1st() =  UE_Log "hello 5" & self.getName()
    proc teeeest() =  UE_Log "hello 5" & self.getName()
    proc teeeest2() =  UE_Log "hello 5" & self.getName()
    proc teeeest3() =  UE_Log "hello 5" & self.getName()
    proc teeee2teeeest() =  UE_Log "hello 5" & self.getName()
    proc teeee2est() =  UE_Log "hello 5" & self.getName()
    proc teeee2es2t() =  UE_Log "hello 5" & self.getName()
    proc teeee1st() =  UE_Log "hello 21" & self.getName()
    