import unittest2
include chess/uci

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

    echo parsedCombo

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

