import std/[json, os, strformat,strutils, sequtils, options, jsonutils]
import ../codegen/[genmodule, makestrproc]

import ../../buildscripts/nimforueconfig
import ../../.reflectiondata/ueproject

genProjectBindings(project, "./")