include ../unreal/prelude


uStruct FStructExample:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
        propString: FString
        propString2: FString
        propInt: int32
        propInt64: int
        propInt642: int64
        propFloat32: float32
        propBool: bool
        propObject: UObjectPtr
        propClass: UClassPtr
        propSubClass: TSubclassOf[AActor]
        propArray: TArray[FString]
        propArrayFloat: TArray[float]
        propArrayBool: TArray[bool]
        propAnother: int
        propAnother2: int
        propAnother3: int
        propAnother22: int
        propAnother31: int
        propAnother32: int
        # propMapFloat : TMap[FString, float]


    uprop(EditAnywhere, BlueprintReadOnly):
        propReadOnly: FString
        propFloat: float
        propFloat64: float64
        propFName: FName