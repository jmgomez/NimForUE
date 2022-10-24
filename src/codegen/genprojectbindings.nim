import std/[json, os, strformat,strutils, sequtils, options, jsonutils]
import ../nimforue/typegen/models
import ../nimforue/macros/[genmodule, makestrproc]

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




# macro saveProjectAsPrev(ueProject: static UEProject) = 
#   var ueProject = ueProject
#   ueProject.modules = ueProject.modules.mapIt(
#       UEModule(name: it.name, hash: it.hash, types: @[], dependencies: @[], rules: @[], isVirtual:it.isVirtual))
#     # UEModule(name:it.name, hash:it.hash))
#   let ueProjectAsStr = $ueProject
#   let codeTemplate = """
# import ../nimforue/typegen/models
# const project* = $1
# """
#   writeFile("src" / ".reflectiondata" / "prevueproject.nim", codeTemplate % [ueProjectAsStr])


# saveProjectAsPrev(ueproject.project)