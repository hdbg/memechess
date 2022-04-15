import shared/[frames, proto]
import std/[asyncdispatch, options, random, strformat, math]
import std/[tables]
import ws
import services/[commands, config]
import chess/[engine, uci]
import chronicles

type
  GameState = object
    info: ChessGameStart
    fen: Option[string]
    moves: seq[string]

    score: int
    clock: ChessClock
    ply: uint

    opts: EvalResult

    config: Option[Config]

  FishMode = enum fmOff, fmLegit, fmRage, fmManual, fmAdvisor

  FishState = object
    mode: FishMode
    autosearch: bool

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn*: WebSocket

    engine: ChessEngine
    configs: ConfigManager

    gameState: GameState
    fishState: FishState

proc echo(fs: FishServer, text: string) {.async.} =
  await fs.conn.send(framify(TerminalOutput(text: text)))

proc prepareLimit(fs: FishServer, vars: EvalVars) =
  var suitableMode: ConfigKind

  case fs.fishState.mode
  of fmLegit:
    suitableMode = ckLegit
  of fmRage:
    suitableMode = ckRage
  of fmAdvisor:
    suitableMode = ckAdvisor
  of fmManual, fmOff: return

  for c in fs.configs.configs:
    if c.kind != suitableMode: continue
    if fs.gameState.info.time notin c.time: continue

    fs.gameState.config = some(c)

  try:
    fs.gameState.opts = get(fs.gameState.config).eval(vars)

    info "config.used", name=get(fs.gameState.config).name
    return
  except ValueError as e:
    echo e.msg

  raise ValueError.newException("No suitable config found")

proc eval(fs: FishServer): GuiMessage =
  var evVars = EvalVars(my_score: fs.gameState.score, enemy_score: -fs.gameState.score, ply: fs.gameState.ply)

  if fs.gameState.info.side == csWhite:
    evVars.my_time = uint(fs.gameState.clock.white)
    evVars.enemy_time = uint(fs.gameState.clock.black)
  else:
    evVars.enemy_time = uint(fs.gameState.clock.white)
    evVars.my_time = uint(fs.gameState.clock.black)

  fs.prepareLimit(evVars)
  let evaluated = fs.gameState.opts

  result = GuiMessage(kind: gmkGo)
  result.movetime = some(evaluated.thinktime)

  fs.engine["UCI_LimitStrength"].check = true

  let uciElo = fs.engine["UCI_Elo"]
  uciElo.spin = math.clamp(int(evaluated.elo), uciElo.min..uciElo.max)

proc sendInfo(fs: FishServer, msg: EngineMessage) {.async.} =
  let info = msg.info

  var output: string

  if info.score.isSome and info.score.get.kind == eskCp:
    let
      score = info.score.get
      val = if score.value.isSome: score.value.get else: 0
      prefix = if val < 0: '-' else: '+'
      color = if val < 0: "#" elif val == 0: "#dfdb21" else: "#52ec29"

    fs.gameState.score = val

    output.add &"[[b;{color};]{$prefix}{$abs(val)}] "
    # output.add &"{prefix}{$val} "

    if info.nodes.isSome:
      output.add &"nodes={$info.nodes.get} "

    if info.nps.isSome:
      output.add &"nps={$info.nps.get} "

    if info.depth.isSome:
      output.add &"depth={$info.depth.get}"

    # await fs.echo(output)

proc queryEngine(fs: FishServer) {.async.} =
  if fs.fishState.mode == fmOff: return
  let nextToMove = if len(fs.gameState.moves) mod 2 == 0: csWhite else: csBlack

  debug "side", next=nextToMove, saved=fs.gameState.info.side
  if nextToMove != fs.gameState.info.side: return
  info "engine.search", toMove=nextToMove

  let pos = GuiMessage(kind: gmkPosition, moves: fs.gameState.moves)

  var limit = fs.eval() # Config invoke here

  debug "config.eval", data=limit

  var best: EngineMessage
  for msg in fs.engine.search(pos, limit, game_id=fs.gameState.info.id):
    if msg.kind == emkInfo:
      await fs.sendInfo(msg)
    elif msg.kind == emkBestMove:
      best = msg

  let step = EngineStep(move: best.bestmove, delay: fs.gameState.opts.delay)
  await fs.conn.send framify(step)

  debug "engine.best", step=step

include modules/cmds
include modules/events

proc newFishServer*(): FishServer {.gcsafe.} =
  randomize()

  new result

  result.proto = FramesHandler()
  result.commands = newCommandDispatcher()
  result.configs = newConfigManager()
  result.engine = newChessEngine("engine.exe")

  result.commandsRegister()
  result.eventsRegister()

proc handle*(fs: FishServer, msg: string) = fs.proto.dispatch(msg)
