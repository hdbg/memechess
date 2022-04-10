import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch, options, random]
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

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn*: WebSocket

    engine: ChessEngine

    state: GameState

proc queryEngine(fs: FishServer) {.async.} =
  echo len(fs.state.moves)

  let nextToMove = if len(fs.state.moves) mod 2 == 0: csWhite else: csBlack
  if nextToMove != fs.state.info.side: return

  info "engine.search", toMove=nextToMove

  let
    pos = GuiMessage(kind: gmkPosition, fen: fs.state.fen, moves: fs.state.moves)
    limit = GuiMessage(kind: gmkGo, movetime: some(100.uint)) # Config invoke here

  var best: EngineMessage
  for msg in fs.engine.search(pos, limit, game_id=fs.state.info.id):
    if msg.kind == emkInfo:
      let info = msg.info

      var short = ShortEngineInfo(
        nodes: info.nodes,
        depth: info.depth,
        nps: info.nps
      )

      if info.score.kind == eskCp:
        short.score = some(info.score.value)

      await fs.conn.send framify(short)
    elif msg.kind == emkBestMove:
      best = msg

  await fs.conn.send framify(EngineStep(move: best.bestmove, delay: 10.uint))



proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} =
  fs.state.info = data
  fs.state.moves = @[]

  if data.steps.len > 0:
    fs.state.fen = some(data.steps[high(data.steps)].fen)

    for step in data.steps:
      fs.state.moves.add step.uci.get

  debug "game.start", d=framify(data), moves=fs.state.moves

  await fs.queryEngine()

proc onGameStep(fs: FishServer, data: ChessStep) {.async.} =
  info "game.step", data=framify(data)

  fs.state.moves.add data.uci.get()

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
    that.commands.dispatch(data.input)

  fh.handle(proto.Ping):
    asyncCheck that.onPing()

proc handle*(fs: FishServer, msg: string) = fs.proto.dispatch(msg)
