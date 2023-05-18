import std/[strutils,options]
#parsers to be used with strscans
func between*(input: string; strVal: var string; start: int, frm, to: char): int =
  var depth = 0
  var frmIdx = -1
  for i, ch in input:
    if ch == frm:
      if depth == 0:
        frmIdx = i
      depth += 1
    elif ch == to:
      depth -= 1
      if depth == 0:
        strVal = input[frmIdx+1..i-1]
        return i

func between*(input: string, strVal: var string; start: int, frm, to:string): int =
  var depth = 0
  var frmIdx = -1
  var i = 0
  while i < input.len:
    if input.substr(i, i+frm.len-1) == frm:
      if depth == 0:
        frmIdx = i
      depth += 1
      i += frm.len
    elif input.substr(i, i+to.len-1) == to:
      depth -= 1
      if depth == 0:
        strVal = input[frmIdx+frm.len..i-1]
        return i + to.len - 1
      i += frm.len
    else:
      i += 1

func between*(input, frm, to: string) : Option[(int, int)] =
  var strVal : string
  let start = input.find(frm)
  if start == -1:
    return none((int, int))
  let res = between(input, strVal, start, frm, to)
  if res == 0: #strscans expects 0 if no match
    return none((int, int))
  return some((start, res))