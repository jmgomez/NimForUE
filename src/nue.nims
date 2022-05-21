##--skipParentCfg # we don't want nue executable in dll directory
when defined windows:
    switch("cc", "vcc")
    switch("passC", "/MP") # multiple processes, force synchronous writes
    switch("outdir", ".") # override config.nims