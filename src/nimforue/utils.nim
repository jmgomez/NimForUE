import std/sequtils

func tail[T]*(xs: seq[T]) : seq[T] =
    if (xs.len == 0):
        return @[]
    else: 
        var temp = xs #TODO does this copy?
        temp.delete(len(xs)-1)
        return temp