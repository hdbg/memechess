# Package

version       = "1.1.1"
author        = "hdbg"
description   = "Memechess: Chess bot software"
license       = "Proprietary"
srcDir        = "src"
bin           = @["memechess"]


# Dependencies

requires "nim >= 1.6.4", "chronicles", "zippy", "ws", "jswebsockets", "mathexpr"
requires "termstyle >= 0.1.0"
requires "parsetoml >= 0.6.0"
requires "nimscripter >= 1.0.13"

when defined(nimdistros):
  import distros
  if detectOs(Ubuntu):
    foreignDep "libssl-dev"
  else:
    foreignDep "openssl"
  foreignDep "upx"

import std/strformat
task release, "Build release":
  const
    binName = when defined(Linux): "memechess" else: "memechess.exe"

  mkdir "bin"
  selfExec &"-d:release,danger,strip --opt:size -o:{binName} --outdir:bin c src/memechess"

  when defined(Linux):
    exec(&"upx -9 bin/{binName}")
