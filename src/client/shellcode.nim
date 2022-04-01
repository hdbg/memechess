import std/[jsffi, options, jsconsole, dom]

import ui

type
  RoundStep = object
    fen: cstring
    ply: cuint

    san, uci: Option[cstring]

  RoundClock = object
    black, white, inc: cint

  RoundVariant = object
    key, name, short: cstring

  RoundGame = object
    fen, id, player, speed: cstring

  RoundOpts = ref object
    clock: RoundClock
    game: RoundGame

    steps: seq[RoundStep]

  ShellCode = ref object
    ui: EvilUi

    opts: RoundOpts

    rawCtrl: JsObject
    rawOpts: JsObject

converter toStep(x: JsObject): RoundStep = to(x, RoundStep)

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.opts = to(opts.data, RoundOpts)

  result.rawCtrl = ctrl
  result.rawOpts = opts

  result.ui = newUI()

  console.log(result)
