import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch]
import ws
import commands
import chronicles
# import mathexpr

import engine, uci

type
  GameState = object
    info: ChessGameStart

    fen: string

    moves: seq[string]

  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn*: WebSocket

    engine: ChessEngine

    state: GameState

proc queryEngine(fs: FishServer) {.async.} =
  let
    pos = GuiMessage(kind: gmkPosition, fen:some(fs.info.fen), moves: fs.info.moves)
    limit GuiMessage(kind: gmkGo, movetime: some(5000.uint)) # Config invoke here

  var bestMove: EngineMessage
  for msg in fs.engine.search(pos, limit, game_id=fs.state.info.id):
    if msg.kind == emkInfo:
      var short = ShortEngineInfo(
        nodes: msg.nodes,
        depth: msg.depth,
        nps: msg.nps
      )

      if msg.score.kind == espCp:
        short.score = some(msg.score.value)

      await fs.conn.send framify(short)
    elif msg.kind == emkBestMove:
      bestMove = msg



proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} =
  fs.state.info = data

  fs.state.fen = data.steps[high(data.steps)].fen

  debug "game.start", d=framify(data)



proc onGameStep(fs: FishServer, data: ChessStep) {.async.} =
  fs.state.moves.add data.uci.get()

  let nextToMove = if data.ply mod 2 == 0: csWhite else: csBlack

  if nextToMove == fs.state.info.side:


proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

proc newFishServer*(): FishServer {.gcsafe.} =
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
