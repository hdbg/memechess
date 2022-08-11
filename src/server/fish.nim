import std/[asyncdispatch, options, random]
import std/[tables, os, strformat]

import shared/[frames, proto]

import ws
import chronicles

import fish/types
import fish/interact/[commands, configs, scripts]
import fish/chess/engine

type
  RunnablePriority {.pure.} = enum Scripts, Configs

  FishState = object
    mode: FishMode
    autosearch: bool
    priority: RunnablePriority

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher

    conn*: WebSocket

    engine: ChessEngine

    configs: ConfigManager
    scripts: ScriptsManager

    state: GameState
    prefs: FishState

proc send[T](fs: FishServer, data: T) {.async.} =
  await fs.conn.send framify(data)

proc echo(fs: FishServer, text: string) {.async.} =
  await fs.send TerminalOutput(text: text)

proc eval(fs: FishServer): Option[EvalResult] =
  let
    vars = initEvalVars(fs.state)
    mode = fs.prefs.mode

  result = fs.scripts.eval(fs.state, vars)
  if result.isSome: return

  result = fs.configs.eval(fs.state, vars, mode)
  if result.isSome: return

  raise IOError.newException("Ало блять шизоїд йобаний, в тебе, сука, ані конфігів, ані скриптів нема тойво")

proc go(fs: FishServer) {.async.} =
  if not fs.state.canMove: return
  if fs.prefs.mode == fmOff:
    debug "fish.off"
    return

  let
    vars = get fs.eval
    msg = fs.engine.query(fs.state, vars)

  let clientMove = EngineStep(
    premove: vars.delay == 0,
    move: msg.bestmove,
    delay: vars.delay
  )

  await fs.send clientMove

  let feedback = fs.engine.feedback

  for info in feedback:
    var message: string
    if info.score.isSome and get(info.score).value.isSome:
      let scoreVal = get(info.score).value.get

      if scoreVal == 0:
        message = &"[[b;yellow;]{scoreVal}"
      elif scoreVal > 0:
        message = &"[[b;green;]+{scoreVal}"
      else:
        message = &"[[b;red;]{scoreVal}"
    else:
      message = "[[;;]"

    if info.depth.isSome: message.add &" depth={info.depth.get}"
    # if info.nps.isSome: message.add &" nps={info.nps.get}"
    # if info.nodes.isSome: message.add &" nodes={info.nodes.get}"
    if info.time.isSome: message.add &" time={info.time.get}"
    if info.currmove.isSome: message.add &" currmove={info.currmove.get}"

    message.add ']'

    await fs.send TerminalOutput(text: message)




proc onGameStart(fs: FishServer, data: GameStart) {.async.} =
  fs.state = GameState()

  if data.steps.len > 0:
    when false:
      # unused for now, but useful for chess960
      fs.state.fen = some(data.steps[high(data.steps)].fen)

    for step in data.steps:
      fs.state.moves.add step.uci.get

  fs.state.info = data

  debug "game.start", moves=fs.state.moves, data=($data)
  fs.scripts.fire(data)

  await fs.go()

proc onGameStep(fs: FishServer, data: Step) {.async.} =
  fs.state.moves.add data.uci.get()

  if data.clock.isSome:
    fs.state.clock = data.clock.get

  fs.state.ply = data.ply

  fs.scripts.fire(data)

  await fs.go()


proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

# =======================================================================================


proc newFishServer*(): FishServer {.gcsafe.} =
  discard existsOrCreateDir("mchess")

  randomize()

  new result

  result.proto = FramesHandler()
  result.commands = newCommandDispatcher()

  result.engine = newChessEngine("mchess" / "engine.exe")

  result.configs = newConfigManager()
  result.scripts = newScriptsManager(result.engine)

  #TEMP
  result.prefs.mode = fmRage

  let
    fs = result
    fh = fs.proto

  fh.handle(proto.GameStart):
    asyncCheck fs.onGameStart(data)

  fh.handle(proto.Step):
    asyncCheck fs.onGameStep(data)

  fh.handle(proto.TerminalInput):
    fs.commands.dispatch(data.text)

  fh.handle(proto.Ping):
    asyncCheck fs.onPing()

proc handle*(fs: FishServer, msg: string) = fs.proto.dispatch(msg)
