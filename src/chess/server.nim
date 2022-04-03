import src/shared/[frames, proto]
import std/[asynchttpserver]
import ws
import commands

type
  FishServer = ref object
    ws: WebSocket
    fh: FramesHandler
    commands: CommandDispatcher

proc onGameStart(fs: FishServer, data: ChessGameStart) {.async.} = discard
proc onGameStep(fs: FishServer, data: ChessStep) {.async.} = discard

proc newFishServer(req: Request): FishServer {.async.} =
  new result

  result.ws = await newWebsocket(req)
  result.fh = newFramesHandler()
  result.commands = newCommandDispatcher()

  fh.addHandler[ChessGameStart](
    proc cb(data: ChessGameStart) = result.onGameStart(data)
  )
  fh.addHandler[ChessStep](
    proc cb(data: ChessStep) = result.onGameStep(data)
  )
  fh.addHandler[TerminalInput](
    proc cb(data: TerminalInput) = result.commands.dispatch(data.input)
  )

proc listen(fs: FishServer) {.async.} =
  while true:
    let packet = await fs.ws.receiveStrPacket()

    fs.fh.handle(packet)
