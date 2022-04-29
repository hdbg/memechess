# Package

version       = "1.0.1"
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
