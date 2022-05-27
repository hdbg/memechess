import unittest2

import server/fish/chess/[engine, uci]
import std/[json, options]

suite "Engine":

  var engine = newChessEngine("tests/engine")

  test "Load":
    check:
      engine.options.len > 0

  test "Search":
    let
      pos = GuiMessage(kind: gmkPosition)
      limit = GuiMessage(kind: gmkGo, movetime: some(1000.uint))

    var lastMsg: EngineMessage
    for m in engine.search(pos, limit, "test"): lastMsg = m

    check:
      lastMsg.kind == emkBestMove
