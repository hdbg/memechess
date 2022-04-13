import shared/[frames, proto]
import std/[asyncdispatch, options, random, strformat, math]
import ws
import commands
import chronicles
import config
# import mathexpr

import engine, uci

type
  GameState = object
    info: ChessGameStart
    fen: Option[string]
    moves: seq[string]

    score: int
    clock: ChessClock

    opts: EvalResult

  FishMode = enum fmOff, fmLegit, fmRage, fmManual ,fmAdvisor

  FishState = object
    mode: FishMode

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn*: WebSocket

    engine: ChessEngine
    configs: ConfigManager

    gameState: GameState
    fishState: FishState

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
    try:
      fs.gameState.opts = c.eval(vars)

      info "config.used", name=c.name

      return
    except ValueError:
      continue

proc eval(fs: FishServer): GuiMessage =
  var evVars = EvalVars(my_score: fs.gameState.score, enemy_score: -fs.gameState.score)

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

  fs.engine.getOption("UCI_LimitStrength").check = true

  let uciElo = fs.engine.getOption("UCI_Elo")
  uciElo.spin = math.clamp(int(evaluated.elo), uciElo.min..uciElo.max)

proc sendInfo(fs: FishServer, msg: EngineMessage) {.async.} =
  let info = msg.info

  var output: string

  if info.score.isSome and info.score.get.kind == eskCp:
    let
      score = info.score.get
      val = if score.value.isSome: score.value.get else: 0
      prefix = if val < 0: '-' else: '+'
      color = if val < 0: "#ec3829" elif val == 0: "#dfdb21" else: "#52ec29"

    fs.gameState.score = val

    output.add &"[[b;{color};]{$prefix}{$abs(val)}] "
    # output.add &"{prefix}{$val} "

    if info.nodes.isSome:
      output.add &"nodes={$info.nodes.get} "

    if info.nps.isSome:
      output.add &"nps={$info.nps.get} "

    if info.depth.isSome:
      output.add &"depth={$info.depth.get}"

    await fs.conn.send framify(TerminalOutput(text: output))

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


proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} =
  fs.gameState = GameState()

  if data.steps.len > 0:
    fs.gameState.fen = some(data.steps[high(data.steps)].fen)

    for step in data.steps:
      fs.gameState.moves.add step.uci.get

  fs.gameState.info = data

  debug "game.start", moves=fs.gameState.moves, data=($data)

  await fs.queryEngine()

proc onGameStep(fs: FishServer, data: ChessStep) {.async.} =
  fs.gameState.moves.add data.uci.get()

  if data.clock.isSome:
    fs.gameState.clock = data.clock.get

  info "game.step", moves = fs.gameState.moves

  await fs.queryEngine()


proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

proc newFishServer*(): FishServer {.gcsafe.} =
  randomize()

  new result

  result.proto = FramesHandler()
  result.commands = newCommandDispatcher()
  result.configs = newConfigManager()
  result.engine = newChessEngine("engine")

  # TODO: Terminal command to change mode
  result.fishState.mode = fmRage

  var
    that = result
    fh = result.proto

  fh.handle(proto.ChessGameStart):
    asyncCheck that.onGameStart(data)

  fh.handle(proto.ChessStep):
    asyncCheck that.onGameStep(data)

  fh.handle(proto.TerminalInput):
    that.commands.dispatch(data.text)

  fh.handle(proto.Ping):
    asyncCheck that.onPing()

proc handle*(fs: FishServer, msg: string) = fs.proto.dispatch(msg)
