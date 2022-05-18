
![This is an image](./logo.png)



### Why NimForUE?

The core idea is to have a short feedback loop while having native performance and a modern language that can access to all features Unreal provides. 

The plugin outputs native dynamic libraries (dlls) that are hooked into UnrealEngine. 

The design philosophy is to dont change any unreal convention on the API side of things, so anyone that knows Unreal can reuse its knowledge. The code guidelines follows (for the most part) the Nim conventions when no in contradiction with the Unreal ones. 


### Why Nim?


Nim is easy to read, fast, with a good type system a fantastic macro system and it also has the best C++ interop in the industry. 

The compiler is incredible fast and it's about to get faster with incremental compilation. 

The performance is the same as with C++ because you are outputting C++ with no overhead (no C types sitting in the middle that you would require with a language like Rust). 

Fully control of the memory if you want to (including move semantics). 

Nim Type System has everything (and probably more) that you can expect from a typed lang. Generics, sum types, constraints on those and it even has C++ like's concepts (my personal favourite feature from C++).

The macro system is outstanding, just to give you an idea await/async are implemented as a library. The same applies to Pattern Matching. This means (as you will see below) that you can create *typed* DSLs for your Unreal Projects that use the semantics that you want.


### Inspiration 

The major inspiration is the previous NimUE plugin but NimForUE uses a radically different approach, instead of generating C++ code it generates a dynamic library. This allows us to use a debugger and to have a quite fast hot reloading. We also plan to rely on the Unreal's reflection system to automatically bind exposed APIs.

We also got inspiration from the AngelScript plugin. What we like about it is how it sits on top of C++ and allows for generating Blueprint classes and functions in Editor time. Our hope is to dont modify the Engine's sources in order to accomplish this. 

There are more plugins out there that inspired us, (Unreal.clr, Unreal.js.. etc.). The major differentiator factor, apart from the one mentioned above, is that we dont rely in any kind of virtual machine.  



### Roadmap
- [x] Bind Unreal Symbols via C++
- [x] POC for generating new UFuncs implemenation in Nim
- [x] Consume Nim in Unreal via auto generated FFI
- [x] Hot Reloading Windows
- [x] Hot Reloading MacOS
- [x] Debugging
- [ ] Test Nim code that consumes Unreal Code without starting the editor. 
- [ ] Cover all Unreal Reflected Types
- [ ] Getter/Setters macro for UProps
- [ ] Generate Nim definitions from Unreal Reflection system 
- [ ] Make builds work on Windows 
- [ ] Make builds work on MacOS 
- [ ] Make builds work ok iOS
- [ ] Make builds work on Android 

- [ ] Being able to produce new UE types from Nim

- [ ] Macro (pragma) for implmenting UFuncs in nim

    ```nim
        proc myFunc(strg: FString) : {. ufunc: params .}
            nimCodeHere

- [ ] DSL for defining UClasses

    ```nim
        uclass MyClass of UObject = 
            uprops(EditAnywhere, BlueprintReadOnly...)
                MyProp : FString
                MyProp2 : int
            uprops(MoreParams..)
                ...
                More props

    ```


- [ ] Improve Debugger
- [ ] REPL
- [ ] Editor Extension for auto completation on the DSL


## Acknowledgments

Thanks to the Nim community for its support, in particular to its Discord channel and also to the forums. Special thanks goes to Don, (@geekrelief) for his help on the Nim side of things.

I would also like to acknowledge the Unreal Slackers discord for its support and in particular, to Mark (@MarkJGx) for his help on the Unreal side. 