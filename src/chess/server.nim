import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch, options, random, strformat]
import ws
import commands
import chronicles
# import mathexpr

import engine, uci

type
  GameState = object
    info: ChessGameStart
    fen: Option[string]
    moves: seq[string]


  FishMode = enum fmOff, fmLegit, fmRage, fmManual , fmAdvisor

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn*: WebSocket

    engine: ChessEngine

    mode: FishMode

    state: GameState

proc queryEngine(fs: FishServer) {.async.} =
  let nextToMove = if len(fs.state.moves) mod 2 == 0: csWhite else: csBlack

  debug "side", next=nextToMove, saved=fs.state.info.side

  if nextToMove != fs.state.info.side: return

  info "engine.search", toMove=nextToMove

  let
    pos = GuiMessage(kind: gmkPosition, moves: fs.state.moves)
    limit = GuiMessage(kind: gmkGo, movetime: some(100.uint)) # Config invoke here

  var best: EngineMessage
  for msg in fs.engine.search(pos, limit, game_id=fs.state.info.id):
    if msg.kind == emkInfo:
      let info = msg.info

      var output: string

      if info.score.isSome and info.score.get.kind == eskCp:
        let
          score = info.score.get

          val = if score.value.isSome: score.value.get else: 0
          prefix = if val < 0: '-' else: '+'
          color = if val < 0: "#52ec29" else: "#ec3829"

        output.add &"[[b;{color};]{prefix}{$val}] "

      if info.nodes.isSome:
        output.add &"nodes={$info.nodes.get} "

      if info.nps.isSome:
        output.add &"nps={$info.nps.get} "

      if info.depth.isSome:
        output.add &"depth={$info.depth.get}"

      # await fs.conn.send framify(TerminalOutput(text: output))
    elif msg.kind == emkBestMove:
      best = msg

  let step = EngineStep(move: best.bestmove, delay: rand(400).uint)
  await fs.conn.send framify(step)

  debug "engine.best", step=step


proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} =
  fs.state = GameState()

  if data.steps.len > 0:
    fs.state.fen = some(data.steps[high(data.steps)].fen)

    for step in data.steps:
      fs.state.moves.add step.uci.get

  fs.state.info = data

  debug "game.start", moves=fs.state.moves, data=($data)

  await fs.queryEngine()

proc onGameStep(fs: FishServer, data: ChessStep) {.async.} =
  fs.state.moves.add data.uci.get()

  info "game.step", moves = fs.state.moves

  await fs.queryEngine()


proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

proc newFishServer*(): FishServer {.gcsafe.} =
  randomize()

  new result

  result.proto = FramesHandler()
  result.commands = newCommandDispatcher()

  result.engine = newChessEngine("engine")

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
