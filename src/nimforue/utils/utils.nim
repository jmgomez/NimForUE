import std/[options, strutils, sequtils, sugar]
import std/[sequtils, options]
#NOTE Do not include UE Types here

func head*[T](xs: seq[T]) : Option[T] =
  if len(xs) == 0:
      return none[T]()
  return some(xs[0])

func any*[T](xs: seq[T]) : bool = len(xs) != 0
    

func tail*[T](xs: seq[T]) : seq[T] =
    if (xs.len == 0):
        return @[]
    else: 
        var temp = xs #TODO does this copy?
        temp.delete(len(xs)-1)
        return temp

func mapi*[T, U](xs : seq[T], fn : (t : T, idx:int)->U) : seq[U] = 
    var toReturn : seq[U] = @[] #Todo how to reserve memory upfront to avoid reallocations?
    for i, x in xs:
        toReturn.add(fn(x, i))
    toReturn


# func bind*[T, U](opt:T, fn : (t : T)->U) : Option[U] = 
#     if 

func spacesToCamelCase*(str:string) :string = 
    str.split(" ")
       .map(str => ($str[0]).toUpper() & str.substr(1))
       .foldl(a & b, "")