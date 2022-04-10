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

    rawCtrl, rawOpts, chessground: JsObject

    apiMove: proc(movedata: JsObject): JsObject

proc onEngineStep(sc: ShellCode, step: EngineStep) =
  let
    before = step.move[0..1]
    after = step.move[2..3]

  var promotion: JsObject = jsUndefined

  if step.move.len > 4:
    const promotionTable = {'q':"queen", 'n':"knight", 'r':"rook", 'b':"bishop"}.toTable
    promotion = promotionTable[step.move[5]].toJs

  sc.chessground.selectSquare(before)

  type
    MoveMetaData = object
      premove: bool
      captured: string

  proc cb =
    sc.rawCtrl.onUserMove(before, after, MoveMetaData(premove: step.premove))
    sc.chessground.move(before, after)

  if step.delay > 0:
    discard setTimeout(cb, step.delay.int)
  else: cb()

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

    echo realStep

    sc.conn.send framify(realStep).cstring

  sc.rawCtrl.socket.handlers.move = toJs(moveHook)

proc setupUI(sc: ShellCode) {.inline.} =
  let tc = TerminalCfg(height: 100, width: 300)

  createAnchor("game__meta", "fish-gui")

  sc.terminal = newTerminal("#fish-gui".toJs, tc) do(cmd: string):
    var data = framify(TerminalInput(input: cmd)).cstring
    sc.conn.send data

proc setupProto(sc: ShellCode) =
  sc.protocol.handle(EngineStep):
    sc.onEngineStep(data)

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =

  if opts.data.game.status.id.to(int) != 20:
    quit()

  new result

  console.log opts

  result.rawCtrl = ctrl
  result.rawOpts = opts
  result.chessground = ctrl.chessground

  result.protocol = FramesHandler()

  result.setupHooks
  result.setupUI
  result.setupProto

  var conn = newWebsocket("ws://localhost:8080/fish")

  conn.onOpen = proc(event: Event) =
    conn.send(framify(createStart opts).cstring)

    discard setInterval(proc = conn.send((framify Ping()).cstring), delay = 3000)

  conn.onMessage = proc(e: MessageEvent) =
    result.protocol.dispatch $e.data

  result.conn = conn
