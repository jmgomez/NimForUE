include unrealprelude

when not WithEditor:
  proc NimMain() {.importc, exportc.}

#TODO import libraries
import game