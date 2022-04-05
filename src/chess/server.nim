import src/shared/[frames, proto]
import std/[asynchttpserver, asyncdispatch]
import ws
import commands
import chronicles

type
  FishServer* = ref object
    ws: WebSocket
    fh: FramesHandler
    commands: CommandDispatcher

proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} = discard
proc onGameStep(fs: FishServer, data: ChessStep) {.async.} = discard
proc onPing(fs: FishServer) {.async.} = await fs.ws.send(framify(PingResponse()))

proc newFishServer*(req: Request): Future[FishServer] {.async, gcsafe .} =
  new result

  result.ws = await newWebsocket(req)

  result.fh = FramesHandler()
  result.commands = newCommandDispatcher()

  var
    that = result
    fh = result.fh

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

proc listen*(fs: FishServer) {.async.} =
  var
    ws = fs.ws
    fh = fs.fh

  while fs.ws.readyState == Open:
    try:
      let packet = await ws.receiveStrPacket()

      fh.handle(packet)
    except WebSocketClosedError as e:
      error "shitsocket.crash", e=repr(e)
      echo e.msg

      return
