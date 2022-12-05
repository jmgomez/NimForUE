switch("outdir", ".") #override config.nims, output to the plugin folder instead of Binaries/nim
switch("mm", "arc")
switch("threads", "on")
switch("tlsEmulation", "off")

when defined(windows):
  --cc:vcc
else:
  --cc:clang
# switch("define:pluginDir", getCurrentDir())

--d:nue