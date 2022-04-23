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

    vine: HTMLAudioElement

proc onEngineStep(sc: ShellCode, step: EngineStep) =
  let
    before = step.move[0..1]
    after = step.move[2..3]

  echo step
  echo @[before, after]

  var promotion: JsObject = jsUndefined

  if step.move.len > 4:
    const promotionTable = {'q':"queen", 'n':"knight", 'r':"rook", 'b':"bishop"}.toTable
    promotion = promotionTable[step.move[4]].toJs

  sc.chessground.selectSquare(before)

  type
    MoveMetaData = object
      premove: bool
      captured: string
      holdtime: JsObject

  var meta = MoveMetaData(premove: step.premove)

  proc cb() =
    meta.holdtime = sc.chessground.state.hold.stop()

    when defined exp:
      sc.rawCtrl.sendMove(before.cstring, after.cstring, promotion.cstring, meta)
    else:
      sc.rawCtrl.onUserMove(before.cstring, after.cstring, meta)

    sc.chessground.move(before, after)

  if step.delay > 0:
    discard setTimeout(cb, step.delay.int)
  else: cb()

proc onTerminalOutput(sc: ShellCode, output: TerminalOutput) =
  echo output.text
  echo type(output.text)
  print(sc.terminal, cstring(output.text))

# ==========
# Setup shit
# ==========

proc setupHooks(sc: ShellCode) =
  sc.apiMove = sc.rawCtrl.socket.handlers.move.to(typeof(sc.apiMove))

  proc moveHook(step: JsObject): JsObject =
    result = sc.apiMove(step)

    sc.vine.currentTime = cfloat(0.0)
    sc.vine.play()

    let
      ply = sc.rawCtrl.lastPly()

    console.log("Another step: ".cstring, sc.rawCtrl.stepAt(ply))

    var realStep = Step(fen: $step.fen,san: some($step.san), ply: step.ply.to(uint))

    case realStep.san.get
    of "O-O":
      realStep.uci = if realStep.ply mod 2 == 0: some("e8g8") else: some("e1g1")
    of "O-O-O":
      realStep.uci = if realStep.ply mod 2 == 0: some("e8c8") else: some("e1c1")
    else:
      realStep.uci = some($step.uci)

    if step.clock != jsUndefined:
      realStep.clock = some(
          Clock(
            white: step.clock.white.to(float),
            black: step.clock.black.to(float)
          )
        )
    echo realStep

    sc.conn.send framify(realStep).cstring

  sc.rawCtrl.socket.handlers.move = toJs(moveHook)

proc setupUI(sc: ShellCode) =
  let tc = TerminalCfg(height: 100, width: 300, name: "Memechess Terminal".cstring, greetings: "Memechess Command Center (c) v.1.0".cstring, prompt: "mc> ", outputLimit: 0)

  createAnchor("game__meta", "fish-gui")

  sc.terminal = newTerminal("#fish-gui".toJs, tc) do(cmd: cstring):
    var data = framify(TerminalInput(text: $cmd)).cstring
    sc.conn.send data

  sc.terminal.resize(300, 100)

proc setupProto(sc: ShellCode) =
  sc.protocol.handle(EngineStep):
    if sc.rawOpts.data.game.status.id.to(int) != 20: return
    sc.onEngineStep(data)

  sc.protocol.handle(TerminalOutput):
    sc.onTerminalOutput(data)

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.rawCtrl = ctrl
  result.rawOpts = opts
  result.chessground = ctrl.chessground

  result.vine = newAudio("https://www.myinstants.com/media/sounds/vine-boom.mp3".cstring)

  result.protocol = FramesHandler()

  result.setupHooks
  result.setupUI
  result.setupProto

  console.log result.terminal.settings()

  var conn = newWebsocket("ws://localhost:8080/fish")

  when not defined release:
    console.log opts
    console.log result

  conn.onOpen = proc(event: Event) =
    conn.send(framify(createStart opts).cstring)

    # discard setInterval(proc = conn.send((framify Ping()).cstring), delay = 3000)

  conn.onMessage = proc(e: MessageEvent) =
    result.protocol.dispatch $e.data

  result.conn = conn


