import std/[json, os, strformat, options, jsonutils]
import ../nimforue/typegen/models
import ../nimforue/macros/genmodule
import ../buildscripts/nimforueconfig

static:
  #TODO load it as NimLiteral which should be way faster
  const projectJsonPath = "./.reflectiondata/ueproject.json" 
  const prevProjectJsonPath = "./.reflectiondata/ueproject_prev.json" 
  const projectJsonContent = readFile(projectJsonPath)
  const project = parseJson(projectJsonContent).jsonTo(UEProject)
  const prevProject =
    if fileExists(prevProjectJsonPath):
      some parseJson(readFile(prevProjectJsonPath)).jsonTo(UEProject)
    else: none[UEProject]()

  genProjectBindings(prevProject, project, "./")


  #update file for next run
  writeFile(prevProjectJsonPath, projectJsonContent)
  echo "File updated"
