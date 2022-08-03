include ../unreal/prelude

#Nim UClasses can derive from the same classes that blueprints can derive from.

uClass AExampleActor of AActor:
    (BlueprintType, Blueprintable) #Class specifiers follow the C++ convention. 
    uprops(EditAnywhere, BlueprintReadWrite): #you can declare multiple UPROPERTIES in one block
        exampleValue : FString #They are declare as nim properties. 
        anotherVale : int #notice int in nim is int64. while in c++ it is int32.
        anotherValueInt32 : int32 #this would be equivalent to int32
        predValue : FString = "Hello" #you can assign a default value to a property.
        predValueInt : int =  20 + 10 #you can even use functions (the execution is deferred)
        nameTest : FString = self.getName() #you can even use functions within the actor itself. It is accessible via this or self.

#In general when using the equal symbol in a uClass declaration, a default constructor will be generated.
#you can specify a custom constructor if you want to by defining a regular nim function and adding the pragma uconstructor

proc myExampleActorCostructor(self: AExampleActorPtr, initializer: FObjectInitializer) {.uConstructor.} =
    UE_Log "The constructor is called for the actor"
    self.anotherVale = 5
    #you can override the values set by the default constructor too since they are added adhoc before this constructor is called.
    self.predValue = "Hello World"

#Notice that you rarelly will need to define a custom constructor for your class. Since the CDO can be set within the DSL. 

#UFunctions

#UFunctions can be added by adding the pragma uFunc, and for each meata, another pragma:
#Since in nim functions are separated from the type they are declared in, you need to specify the type as the first argument.

proc myUFunction(self: AExampleActorPtr, param : FString) : int32 {. ufunc, BlueprintCallable .} = 
    UE_Log "UFunction called"
    5

#You can also use the uFunctions macro to declare multiple uFunctions at once. This is the preferred way.
uFunctions:
    (BlueprintCallable, self:AExampleActorPtr) #you must specify the type and any shared meta like this.

    proc anotherUFunction(param : FString) : int32 = 10 #now you can define the function as you normally would.
    proc yetAnotherUFunction(param : FString) : FString = 
        self.getName() #you can access to the actor itself by the name you specify in the uFunctions macro.
    
    proc customPragma(param : FString) : int32 {. BlueprintPure .} = 10 #you can also specify custom pragmas per functions rather than creating a new block

    proc callFromTheEditor() {. CallInEditor .} = 
        UE_Log "Call from the editor"
        