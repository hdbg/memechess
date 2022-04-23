# Package

version       = "1.0.0"
author        = "hdbg"
description   = "A lichess bot"
license       = "Proprietary"
srcDir        = "src"
bin           = @["memechess"]


# Dependencies

requires "nim >= 1.6.4", "chronicles", "zippy", "ws", "jswebsockets", "mathexpr"
requires "fab >= 0.4.3"
requires "toml_serialization >= 0.2.0"
requires "parsetoml >= 0.6.0"
requires "nimscripter >= 1.0.13"