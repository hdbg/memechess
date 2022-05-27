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

proc buildRelease(name: string, opts: string = "",  upx: bool = false) =
  mkdir "bin"

  selfExec &"-d:release,danger,strip {opts} --opt:size -o:{name} --outdir:bin c src/memechess.nim"

  if upx:
    exec(&"upx -9 bin/{name}")

task win_release, "Build windows release":
  when defined(Windows):
    buildRelease("memechess.exe")
  elif defined(Linux):
    buildRelease("memechess.exe", "-d:mingw", true)

task linux_release, "Build linux release":
  buildRelease("memechess", upx=true)
