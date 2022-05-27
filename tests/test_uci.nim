import unittest2
include server/fish/chess/uci

suite "Engine-to-GUI":

  test "Bestmove":
    const
      str = "bestmove a2a4"
      str2 = "bestmove a3a4 ponder b2c2"

    assert(parseBestMove(str).bestmove == "a2a4")

    let withPonder = parseBestMove(str2)
    check:
      withPonder.bestmove == "a3a4"
      withPonder.ponder.get == "b2c2"

  test "Engine option (Check)":
    const
      checkStr = "option name Nullmove type check default true"

    let parsedCheck = parseOption(checkStr).option

    check:
      parsedCheck.name == "Nullmove"
      parsedCheck.check == true

  test "Engine option (Spin)":
    const
      spinStr = "option name NalimovCache type spin default 1 min 1 max 32"

    let parsedSpin = parseOption(spinStr).option

    check:
      parsedSpin.name == "NalimovCache"
      parsedSpin.spin == 1
      parsedSpin.min == 1
      parsedSpin.max == 32

  test "Engine option (Combo)":
    const comboStr = "option name Style type combo default Normal var Solid var Normal var Risky"

    let parsedCombo = parseOption(comboStr).option

    check:
      parsedCombo.name == "Style"
      parsedCombo.combo == "Normal"
      parsedCombo.values == @["Solid", "Normal", "Risky"]

  test "Engine option (String)":
    const
      stringStr = "option name NalimovPath type string default c:\\\n"

    check:
      parseOption(stringStr).option.str == "c:\\"

  test "Engine option (Button)":
    const
      buttonStr = "option name Clear_Hash type button\n"

    let parsedButton = parseOption(buttonStr).option

    check:
      parsedButton.name == "Clear_Hash"
      parsedButton.kind == eokButton

  test "Engine info parse":
    const
      infoStr = "info depth 15 nodes 23454 pv a2a4 a5a6 b7c4"

    let msg = parseInfo(infoStr).info

    check:
      msg.depth.get == 15
      msg.nodes.get == 23454
      msg.pv.get == @["a2a4", "a5a6", "b7c4"]

suite "GUI-to-engine":

  test "debug":
    let msg = GuiMessage(kind: gmkDebug, debug: true)

    check:
      $msg == "debug true\n"

  test "setoption":
    let
      firstMsg = GuiMessage(kind: gmkSetOption, name: "Cache")
      secondMsg = GuiMessage(kind: gmkSetOption, name: "Cache", value: some("L2"))

    check:
      $firstMsg == "setoption name Cache\n"
      $secondMsg == "setoption name Cache value L2\n"

  test "position":
    let
      emptyMsg = GuiMessage(kind: gmkPosition)
      withFen = GuiMessage(kind: gmkPosition, fen: some("sd2f2f2dvdf"))

      justMoves = GuiMessage(kind: gmkPosition, moves: @["a2a4", "b1c3", "h7h8"])
      fenAndMoves = GuiMessage(kind: gmkPosition, fen: some("asa2f"), moves: @[
          "a2a4", "a6a8", "c1c2"])

    check:
      $emptyMsg == "position startpos\n"
      $withFen == "position fen sd2f2f2dvdf\n"
      $justMoves == "position startpos moves a2a4 b1c3 h7h8\n"
      $fenAndMoves == "position fen asa2f moves a2a4 a6a8 c1c2\n"

  test "go":
    let
      simple = GuiMessage(kind: gmkGo, wtime: some(34563.uint), btime: some(
          23213.uint), depth: some(20.uint))
      searchMoves = GuiMessage(kind: gmkGo, wtime: some(123.uint),
          searchmoves: @["a2c4", "b2b4"])

    check:
      $simple == "go wtime 34563 btime 23213 depth 20\n"
      $searchMoves == "go wtime 123 searchmoves a2c4 b2b4\n"

