import std/[json, os, strformat,strutils, sequtils, options, jsonutils]
import ../nimforue/codegen/models
import ../nimforue/codegen/[genmodule, makestrproc]

import ../buildscripts/nimforueconfig
import ../.reflectiondata/ueproject

genProjectBindings(project, "./")

