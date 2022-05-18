
import std/[macros, genasts, osproc]

import sequtils
import sugar



proc appendFile(path: string, content: string) = 
    # if fileExists(path):
    #     echo "FILE EXISTS"
    # else:
    #     echo "FILE DOES NOT EXISTS"
    var str = readFile(path)
    writeFile(path, str & content)


macro ffi* (pathToGenFile: static string, fn : typed) : untyped = 
    #[ Generates the following based on Fn signature 
        proc saluteFFI(name: cstring) : cstring = 
            type SaluteFFIWrapper = proc(name: cstring): cstring {.gcsafe, stdcall.}
            let salute = cast[SaluteFFIWrapper](lib.symAddr("salute"))
            return salute(name)
    ]#
    expectKind(fn, RoutineNodes)
    let fParams = fn.params
    var params = nnkFormalParams.newTree(fparams[0]) # save the return type
    for p in fparams[1..^1]: # convert from sym to ident
        params.add nnkIdentDefs.newTree(ident(p[0].strVal), if not (p[1].kind in [nnkEmpty, nnkProcTy]) : ident(p[1].strVal) else: p[1], p[2])
    let pragmasInner =  nnkPragma.newTree(ident("cdecl"))
    let procSign = nnkProcTy.newTree(params, pragmasInner) 
    let paramsNodesDef = fn.params[1.. ^1]
    let paramsNamesAsIdentNodes = paramsNodesDef.map(p=>(ident($p[0]))) #param names to ident nodes

    var callNode = nnkCall.newTree(newIdentNode("fun"))
    callNode.add(paramsNamesAsIdentNodes)
    let doesReturn = not((repr fn.params[0]) == "void" or fn.params[0].kind == nnkEmpty)
    if doesReturn:
        callNode = nnkReturnStmt.newTree(callNode)

    let procFFIBody = genAst(fnSymbolName = $fn.name, procSign, callNode):
        type ProcType {. inject .} = procSign 
        withLock libLock:
            let fun {. inject .} = cast[ProcType](lib.symAddr(fnSymbolName))
            callNode
    # echo treeRepr fn
    var ffiProc = fn.copy()
    ffiProc[0] = nnkPostfix.newTree(ident("*"), ffiProc[0]) #Make them public so it's easier to test the workflos when runFFI
    ffiProc.body = procFFIBody

    when defined genffi:
        appendFile(pathToGenFile, ffiProc.repr & "\n")
    
    result = fn
   
