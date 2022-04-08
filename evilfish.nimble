# Package

version       = "0.1.0"
author        = "hdbg"
description   = "A lichess bot"
license       = "Proprietary"
srcDir        = "src"
bin           = @["evilfish"]


# Dependencies

requires "nim >= 1.6.4", "chronicles", "zippy", "ws", "jswebsockets", "mathexpr"
