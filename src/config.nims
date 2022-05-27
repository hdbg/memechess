switch("define", "ssl")
switch("mm", "arc")
switch("deepcopy", "on")

switch("path", ".")
switch("path", "..")
switch("path", "...")
switch("path", "$nim")

# Logging config
switch("define", "chronicles_sinks=textblocks[stdout,file(mchess/info.log)]")
