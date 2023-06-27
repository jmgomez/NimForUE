import std/[macros, genasts, json, bitops, sequtils, strutils]
import models
when defined(nuevm):
  import vmtypes
  export vmtypes    
else:
  import ../unreal/coreuobject/uobjectflags
  export uobjectflags

when defined(nuevm):
  macro genEnumOperators(eSym, typSym:typed, genValConverters : static bool = true) : untyped = 
      let enumName = eSym.strVal()
      let enumType = typSym.strVal()
      let name = ident enumName
      let typ = ident enumType
      let enu = eSym.getImpl()
      
      let enumFields = enu[^1].children.toSeq().filterIt(it.kind == nnkEnumFieldDef)        

      let content = newLit(enumFields.mapIt((it[0].strVal, uint64(it[1].intVal()))))
    
      result = genAst(name, eSym, typ, content):
          proc `or`*(a, b : name) : name =  name(typ(ord(a)) or typ(ord(b)))

          proc `||`*(a, b : name) : name {.importcpp:"#|#".}
          proc `&&`*(a, b : name) : name {.importcpp:"#&#".}
          
          # proc `or`*(a, b : name) : name =  name(typ(ord(a)) or typ(ord(b)))
          proc `|`*(a, b : name) : name =  a or b
              # cast[name](bitor(cast[typ](a),cast[typ](b)))

          proc `and`*(a, b : name) : name = name(typ(ord(a)) and typ(ord(b)))
          
          proc `&`*(a, b : name) : name {.importcpp:"#&#".}
              # cast[name](bitand(cast[typ](a),cast[typ](b)))
          
          proc contains*(a,b:name) : bool = (a and b) == a #returns true if used like flag in flags 

          proc fromJsonHook*(self: var name, jsonNode: JsonNode) =
              self = name(jsonNode.getInt()) #we need to this via the int cast otherwise combinations wont work. int should be big enough

          proc toJsonHook*(self:name) : JsonNode = newJInt(int(self))

          proc fields*(eProp : typedesc[name]) : seq[(string, uint64)] = 
              content
                  
          proc `$`*(e : name) : string = 
              let fields = eSym.fields()
              let flagNames = fields.filterIt(bitand(e.uint64, it[1]) != 0).mapIt(it[0])
              flagNames.join(", ")

      let converters = genAst(name, valName=ident enumName&"Val", typ):
          converter toValName*(a:name) : valName = valName(typ(ord(a)))
          converter toName*(a:valName) : name = 
              let val = typ(a)
              #prevents a type overflow when parsing engine types. 
              if val <= (uint64)high(name):
                  name(val)
              else:
                  name(0)
      
      if genValConverters:
          result.add converters


  {.push warning[HoleEnumConv]: off.}
  genEnumOperators(EPropertyFlags, uint64)
  genEnumOperators(EObjectFlags, uint32, false)
  genEnumOperators(EFunctionFlags, uint32)
  genEnumOperators(EClassFlags, uint32, false)
  genEnumOperators(EStructFlags, uint32)
  genEnumOperators(EFieldIterationFlags, uint8, false)
  {.pop.}




  # template `|`*(a, b : untyped) : untyped =  name(typ(ord(a)) or typ(ord(b)))
  # import std/enumutils #
  # template rank*[T:enum | int](a : T) : int = (when a is int: a else: symbolRank(a)) #TODO test if the values match. 
  # # template `|`*[A, B:enum | int](a: A, b: B): enum = (rank(a) + rank(b))
  # template `or`*[A, B:enum | int](a: A, b: B): enum =  a | b


  const CLASS_Inherit* = (CLASS_Transient | CLASS_Optional | CLASS_DefaultConfig | CLASS_Config | CLASS_PerObjectConfig | CLASS_ConfigDoNotCheckDefaults | CLASS_NotPlaceable | CLASS_Const | CLASS_HasInstancedReference | CLASS_Deprecated | CLASS_DefaultToInstanced | CLASS_GlobalUserConfig | CLASS_ProjectUserConfig | CLASS_NeedsDeferredDependencyLoading)
  const CLASS_ScriptInherit* = CLASS_Inherit | CLASS_EditInlineNew | CLASS_CollapseCategories 
  # # #* Struct flags that are automatically inherited */
  const STRUCT_Inherit        = STRUCT_HasInstancedReference | STRUCT_Atomic
  # # #* Flags that are always computed, never loaded or done with code generation */
  #TODO move the values over. Although struct is not even used
  # const STRUCT_ComputedFlags    = STRUCT_NetDeltaSerializeNative | STRUCT_NetSerializeNative | STRUCT_SerializeNative | STRUCT_PostSerializeNative | STRUCT_CopyNative | STRUCT_IsPlainOldData | STRUCT_NoDestructor | STRUCT_ZeroConstructor | STRUCT_IdenticalNative | STRUCT_AddStructReferencedObjects | STRUCT_ExportTextItemNative | STRUCT_ImportTextItemNative | STRUCT_SerializeFromMismatchedTag | STRUCT_PostScriptConstruct | STRUCT_NetSharedSerialization
  const FUNC_FuncInherit*       = (FUNC_Exec | FUNC_Event | FUNC_BlueprintCallable | FUNC_BlueprintEvent | FUNC_BlueprintAuthorityOnly | FUNC_BlueprintCosmetic | FUNC_Const)
  const FUNC_FuncOverrideMatch* = (FUNC_Exec | FUNC_Final | FUNC_Static | FUNC_Public | FUNC_Protected | FUNC_Private)
  const FUNC_NetFuncFlags*      = (FUNC_Net | FUNC_NetReliable | FUNC_NetServer | FUNC_NetClient | FUNC_NetMulticast)
  const FUNC_AccessSpecifiers*  = (FUNC_Public | FUNC_Private | FUNC_Protected)




import std/[macros, typetraits]

proc newLit*(arg: EPropertyFlagsVal): NimNode =
  result = nnkCall.newTree(ident typeof(arg).name,  newLit(arg.uint64))
  
proc newLit*(arg: EFunctionFlagsVal): NimNode =
  result = nnkCall.newTree(ident typeof(arg).name,  newLit(arg.uint64))

proc newLit*(arg: EStructFlagsVal): NimNode =
  result = nnkCall.newTree(ident typeof(arg).name,  newLit(arg.uint64))