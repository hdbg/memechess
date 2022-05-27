import std/[asyncdispatch, options, random]
import std/[tables, os]

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

  result = fs.scripts.eval(fs.state, vars, mode)
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
    premove: vars.premove,
    move: msg.bestmove,
    delay: vars.delay
  )

  await fs.send clientMove

proc onGameStart(fs: FishServer, data: GameStart) {.async.} =
  fs.state = data.initGameState

  debug "game.start", moves=fs.state.moves, data=($data)
  fs.scripts.fire(data)

  await fs.go()

proc onGameStep(fs: FishServer, data: Step) {.async.} =
  fs.state.moves.add data.uci.get()

  if data.clock.isSome:
    fs.state.clock = data.clock

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

  info "memechess.ready"


proc handle*(fs: FishServer, msg: string) = fs.proto.dispatch(msg)
