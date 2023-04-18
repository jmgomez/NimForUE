
import buildcommon, buildscripts, nimforueconfig

proc generatePlugin*(name:string) =
  log "Generating plugin: " & name