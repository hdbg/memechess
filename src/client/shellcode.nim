import std/[jsffi, options, jsconsole, dom, tables]

import api/[terminal, reflect, misc]
import shared/[proto, frames]

import client/utils

import jswebsockets

type
  ShellCode = ref object
    terminal: Terminal
    protocol: FramesHandler
    conn: jswebsockets.WebSocket

    rawCtrl: JsObject
    rawOpts: JsObject

    apiMove: proc(movedata: JsObject): JsObject

proc onCmd(sc: ShellCode, cmd: string) =
  var data = framify(TerminalInput(input: cmd)).cstring
  sc.conn.send data

proc onStep(sc: ShellCode, step: ChessStep) =
  sc.conn.send framify(step).cstring


# ==========
# Setup shit
# ==========

proc setupHooks(sc: ShellCode) =
  sc.apiMove = sc.rawCtrl.socket.handlers.move.to(typeof(sc.apiMove))

  proc moveHook(step: JsObject): JsObject {.inline.} =
    var realStep =
      ChessStep(
        fen: $step.fen,
        san: some($step.san),
        uci: some($step.uci),
        clock: some(
          ChessClock(
            white: step.clock.white.to(float),
            black: step.clock.black.to(float)
          )
        )
      )
    result = sc.apiMove(step)

    that.onStep(move(realStep))

  sc.rawCtrl.socket.handlers.move = toJs(moveHook)

proc setupUI(sc: ShellCode) {.inline.} =
  let tc = TerminalCfg(height: 100, width: 300)

  createAnchor("game__meta", "fish-gui")

  sc.terminal = newTerminal("#fish-gui".toJs, tc) do(cmd: string):
      result.onCmd(cmd)

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.rawCtrl = ctrl
  result.rawOpts = opts

  result.protocol = FramesHandler()

  sc.setupHooks
  sc.setupUI

  var conn = newWebsocket("ws://localhost:8080/fish")

  conn.onOpen() do(e: Event)
    conn.send framify(createStart opts)

    discard setInterval(delay = 400, callback = proc(args: varargs[
        JsObject]) = conn.send (framify Ping()).cstring)

  conn.onMessage() do(e: MessageEvent):
    result.protocol.dispatch $e.data

  result.conn = conn
