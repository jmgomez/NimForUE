
![This is an image](./logo.png)


### DISCLAIMER ###
This is not meant to be used yet. There is no instructions available, but there will be instructions once it's in a better state.  
### Why NimForUE?

The core idea is to have a short feedback loop while having native performance and a modern language that can access all features Unreal provides. 

The plugin outputs native dynamic libraries (DLLs) that are hooked into UnrealEngine. 

The design philosophy is to not change any unreal conventions on the API side of things, so anyone that knows Unreal can reuse its knowledge. The code guidelines follow (for the most part) the Nim conventions when not in contradiction with the Unreal ones. 



### Hot reloading and debugging POC video:

[![Hot reloading and debugging POC video](https://img.youtube.com/vi/4NBE9sEMn28/0.jpg)](https://www.youtube.com/watch?v=4NBE9sEMn28)



### Why Nim?


Nim is fast and easy to read with a good type system and a fantastic macro system, and it also has the best C++ interop in the industry. 

The compiler is incredibly fast, and it's about to get faster with incremental compilation. 

The performance is the same as with C++ because you are outputting C++ with no overhead (no C types sitting in the middle that you would require with a language like Rust). 

Fully control the memory if you so desire (including move semantics). 

Nim Type System has everything (and probably more) that you can expect from a typed lang: generics, sum types, constraints on those, and it even has C++-like concepts (my personal favorite feature from C++).

The macro system is outstanding. Just to give you an idea, await/async are implemented as a library. The same applies to Pattern Matching. This means (as you will see below) that you can create *typed* DSLs for your Unreal Projects that use the semantics that you want.


### Inspiration 

The major inspiration is the previous NimUE plugin but NimForUE uses a radically different approach. Instead of generating C++ code, it generates a dynamic library. This allows us to use a debugger and to have quite fast hot reloading. We also plan to rely on Unreal's reflection system to automatically bind exposed APIs.

We also got inspiration from the AngelScript plugin. What we like about it is how it sits on top of C++ and allows for generating Blueprint classes and functions in Editor time. We hope to not modify the Engine's sources to accomplish this. 

There are more plugins out there that inspired us, (Unreal.clr, Unreal.js.. etc.). The major differentiator factor, apart from the one mentioned above, is that we don't rely on any kind of virtual machine.



### Roadmap
- [x] Bind Unreal Symbols via C++
- [x] POC for generating new UFuncs implemenation in Nim
- [x] Consume Nim in Unreal via auto generated FFI
- [x] Hot Reloading Windows
- [x] Hot Reloading MacOS
- [x] Debugging
- [x] Test Integration via Unreal Frontend
- [x] Cover most Unreal Reflected Types
- [x] Getter/Setters macro for UProps
- [ ] Generate Nim definitions from Unreal Reflection system 
- [x] Being able to produce new UE types from Nim
- [x] Macro (pragma) for implmenting UFuncs in nim

    ```nim
        proc myFunc(strg: FString) : {. ufunc: params .}
            nimCodeHere
- [x] DSL for defining uFunctions in blocks

- [x] DSL for defining UStructs

    ```nim
        uStruct FMyNimStruct:
        (BlueprintType)
        uprop(EditAnywhere, BlueprintReadWrite):
            testField : int32
            testField2 : FString
        uprop(EditAnywhere, BlueprintReadOnly):
            param35 : int32    
    ```

- [x] DSL for defining UEnums

    ```nim
    uEnum EMyEnumCreatedInNim:
        (BlueprintType)
        ValueOne
        SomethingElse
        AnotherThing
    ```

- [x] DSL for defining delegates

    ```nim
        uDelegate FMyDelegate2Params(str:FString, param:TArray[FString])
        uDelegate FMyDelegateNoParams()
    ```

- [x] DSL for defining UClasses

    ```nim
        uClass MyClass of UObject = 
            (Blueprintable, BlueprintType)
            uprops(EditAnywhere, BlueprintReadOnly)
                myProp : FString
                myProp2 : int32
            uprops(MoreParams..)
                ...
                More props
    ```
- [x] Being able to emit most used FProperties

- [x] Being able to emit any type into UE with hotreload

- [x] Allow to define constructors on UObjects

- Shipping Builds
    - [ ] Make builds work on Windows 
    - [ ] Make builds work on MacOS 
    - [ ] Make builds work ok iOS
    - [ ] Make builds work on Android 


- [ ] Nimscripter support? (allows nim in runtime)
- [ ] Improve Debugger
- [ ] Test Nim code that consumes Unreal Code without starting the editor. 
- [ ] REPL
- [ ] Editor Extension for auto completation on the DSL





## Examples

This code can be found at src/examples/actorexample
```nim
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
        
```
Which produces:
![Blueprint](https://media.discordapp.net/attachments/844939530913054752/1004338096160120913/unknown.png)



## Acknowledgments

Thanks to the Nim community for its support, in particular to its Discord channel and also to the forums. Special thanks go to Don, (@geekrelief) for his help on the Nim side of things.

I would also like to acknowledge the Unreal Slackers discord for its support and in particular, to Mark (@MarkJGx) for his help on the Unreal side. 
