include ../unreal/prelude
import std/[sugar, macros, genasts]
import uemeta

#Maybe it should hold the old type, the ptr to the struct and the func gen. So we can check for changes?

type 
    UEEmitter* = ref object 
        uStructsEmitters* : seq[UPackagePtr->UStructPtr]



macro emitType*(typeDef : static UEType, typeDefAsNode : UEType, emitter: var UEEmitter) : untyped = 
    let typeDecl = genTypeDecl(typeDef)
    case typeDef.kind:
        of uClass: discard
        of uStruct:
            let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode, emitter): #defers the execution
                emitter.uStructsEmitters.add (package:UPackagePtr) => toUStruct[name](typeDefAsNode, package)
              

            result = nnkStmtList.newTree [typeDecl, typeEmitter]

        of uEnum: discard


