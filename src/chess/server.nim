import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch]
import ws
import commands

type
  FishServer* = ref object
    ws: WebSocket
    fh: FramesHandler
    commands: CommandDispatcher

proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} = discard
proc onGameStep(fs: FishServer, data: ChessStep) {.async.} = discard

proc newFishServer*(req: Request): Future[FishServer] {.async, gcsafe .} =
  new result

  result.ws = await newWebsocket(req)
  result.fh = FramesHandler()
  result.commands = newCommandDispatcher()

  var fh = result.fh

  fh.addHandler(
    proc(data: ChessGameStart) = asyncCheck result.onGameStart(data)
  )
  fh.addHandler(
    proc(data: ChessStep) = asyncCheck result.onGameStep(data)
  )
  fh.addHandler(
    proc(data: TerminalInput) = result.commands.dispatch(data.input)
  )

proc listen*(fs: FishServer) {.async, gcsafe.} =
  while true:
    let packet = await fs.ws.receiveStrPacket()

    fs.fh.handle(packet)
