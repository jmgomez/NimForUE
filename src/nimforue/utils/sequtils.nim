import std/[sequtils, options]


func head*[T](xs: seq[T]) : Option[T] =
  if len(xs) == 0:
      return none[T]()
  return some(xs[0])

func tail*[T](xs: seq[T]) : seq[T] =
    if (xs.len == 0):
        return @[]
    else: 
        var temp = xs #TODO does this copy?
        temp.delete(len(xs)-1)
        return temp

