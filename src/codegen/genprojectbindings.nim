import std/[json, os, strformat, options, jsonutils]
import ../nimforue/typegen/models
import ../nimforue/macros/genmodule
import ../buildscripts/nimforueconfig
import ../.reflectiondata/ueproject


const reflectionDataDir = "./src/.reflectiondata"
const prevPath = reflectionDataDir / "prevueproject.nim"
when fileExists(prevPath):
  import ../.reflectiondata/prevueproject
  const prevProject = some prevueproject.project
else:
  const prevProject = none[UEProject]()

genProjectBindings(prevProject, ueproject.project, "./")

