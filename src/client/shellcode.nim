import std/[jsffi, options, jsconsole, dom]

import api/terminal
import shared/[proto, frames]

import jswebsockets

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
    terminal: Terminal
    fh: FramesHandler
    ws: WebSocket

    opts: RoundOpts

    rawCtrl: JsObject
    rawOpts: JsObject

converter toStep(x: JsObject): RoundStep = to(x, RoundStep)

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.opts = to(opts.data, RoundOpts)

  result.rawCtrl = ctrl
  result.rawOpts = opts

  block loadTerminal:
    var ancestorRaw = document.getElementsByClassName("game__meta")

    if ancestorRaw.len != 1:
      raise ValueError.newException("Can't find ui root")

    var ancestor = ancestorRaw[0]

    var anchor = document.createElement("div")
    anchor.setAttribute("id", "fish-gui")

    ancestor.appendChild(anchor)

    let terminalConfig = TerminalCfg(height:100, width:300)

    proc onCmd(cmd: string) =
      var data = framify(TerminalInput(input: cmd)).cstring
      result.ws.send data

    result.terminal = newTerminal("#fish-gui".toJs, onCmd ,terminalConfig)

  result.ws = newWebsocket("ws://localhost:8080/fish")
  result.ws.onMessage = proc(e: MessageEvent) =
    result.fh.handle($e.data)

  console.log(result)
