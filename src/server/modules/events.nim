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

  fs.gameState.ply = data.ply

  info "game.step", moves = fs.gameState.moves

  await fs.queryEngine()


proc onPing(fs: FishServer) {.async.} = await fs.conn.send(framify(PingResponse()))

proc eventsRegister(fs: FishServer) =
  let fh = fs.proto

  fh.handle(proto.ChessGameStart):
    asyncCheck fs.onGameStart(data)

  fh.handle(proto.ChessStep):
    asyncCheck fs.onGameStep(data)

  fh.handle(proto.TerminalInput):
    fs.commands.dispatch(data.text)

  fh.handle(proto.Ping):
    asyncCheck fs.onPing()
