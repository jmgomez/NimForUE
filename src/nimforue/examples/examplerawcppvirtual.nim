include ../unreal/prelude
import ../codegen/[gencppclass, models, ueemit]




{.emit:"""/*TYPESECTION*/



class Foo {
public:
  int field1;

  virtual int getField1(){
    return field1;
  }
};

"""
.}

const ClassTemplate = """
  struct $1 : public $3 {
    $2
  };
"""


type 
  Foo {.importcpp, inheritable.} = object
    field1: int32
  FooPtr = ptr Foo
  Boo {.exportc, codegenDecl:ClassTemplate.} = object of Foo
    field2 : int
  BooPtr = ptr Boo
    

proc getField1(foo:FooPtr) : int32 {.importcpp.}


uClass ARawCppActor of AActor:
  ufuncs(CallInEditor):
    proc testRawCpp() =      
      var foo = Foo(field1:20)      
      let fooPtr = foo.addr
      UE_Log "Foo field1 is " & $fooPtr.getField1()
    proc testChild() = 
      var boo = Boo(field1: 10, field2:30)
      let booPtr = boo.addr
      UE_Log "Boo field1 is " & $booPtr.getField1()


# class MyCppClass of 