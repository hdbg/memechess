import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch]
import ws
import commands
import chronicles

type
  FishServer* = ref object
    proto: FramesHandler
    commands: CommandDispatcher
    conn: WebSocket

proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} = discard
proc onGameStep(fs: FishServer, data: ChessStep) {.async.} = discard
proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

proc newFishServer*(conn: WebSocket): FishServer {.gcsafe.} =
  new result

  result.proto = FramesHandler()
  result.commands = newCommandDispatcher()
  result.conn = conn

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
