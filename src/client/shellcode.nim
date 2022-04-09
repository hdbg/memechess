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

    apiMove: proc(movedata: ChessStep): JsObject

    rawCtrl: JsObject
    rawOpts: JsObject


proc onCmd(sc: ShellCode, cmd: string) =
  var data = framify(TerminalInput(input: cmd)).cstring
  sc.conn.send data

proc onStep(sc: ShellCode, step: ChessStep) =
  sc.conn.send framify(step).cstring

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.rawCtrl = ctrl
  result.rawOpts = opts

  result.protocol = FramesHandler()

  console.log opts
  console.log ctrl

  block ui:
    let tc = TerminalCfg(height: 100, width: 300)

    createAnchor("game__meta", "fish-gui")

    result.terminal = newTerminal("#fish-gui".toJs, tc) do(cmd: string):
      result.onCmd(cmd)

  #result.apiMove = to(Reflect.get(ctrl, "apiMove".cstring), typeof(result.apiMove))
  #Reflect.set(ctrl, "apiMove".cstring, toJs(proc(before, after: cstring) = console.log(before, after)))

  result.apiMove = ctrl.socket.handlers.move.to(proc(movedata: ChessStep): JsObject)

  var that = result
  proc moveHook(step: JsObject): JsObject =
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
    result = that.apiMove(realStep)

    that.onStep(move(realStep))


  # Reflect.set(ctrl.socket.handlers, "move".cstring, toJs(moveHook))

  ctrl.socket.handlers.move = toJs(moveHook)
  console.log ctrl

  var conn = newWebsocket("ws://localhost:8080/fish")
  result.conn = conn

  conn.onOpen = proc(event: Event) =
    console.log "socket open"

    let toSend = framify(createStart(opts))
    echo toSend
    conn.send toSend.cstring

    discard setInterval(delay = 400, callback = proc(args: varargs[
        JsObject]) = conn.send (framify Ping()).cstring)
