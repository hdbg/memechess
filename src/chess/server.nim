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

  fh.addHandler(
    proc(data: ChessGameStart) = asyncCheck that.onGameStart(data)
  )
  fh.addHandler(
    proc(data: ChessStep) = asyncCheck that.onGameStep(data)
  )
  fh.addHandler(
    proc(data: TerminalInput) = that.commands.dispatch(data.input)
  )
  fh.addHandler(
    proc(data: Ping) = asyncCheck that.onPing()
  )

proc handle*(fs: FishServer, msg: string) = fs.proto.handle(msg)
