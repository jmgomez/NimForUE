import std/[json, os, strformat,strutils, sequtils, options, jsonutils]
import ../nimforue/typegen/models
import ../nimforue/macros/[genmodule, makestrproc]

import ../buildscripts/nimforueconfig
import ../.reflectiondata/ueproject


const reflectionDataDir = "./src/.reflectiondata"
genProjectBindings(project, "./")

