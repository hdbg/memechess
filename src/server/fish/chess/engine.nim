import std/[osproc, streams, options, math, os, httpclient, json]
import uci
import server/fish/types
import shared/proto

when defined Linux:
  import std/posix

export uci

type
  ChessEngine* = ref object
    program: Process
    stdin, stdout, stderr: Stream

    game_id: string
    feedback: seq[EngineInfo]

    options*: seq[EngineOption]

proc receive(engine: ChessEngine): EngineMessage =
  when false:
    result = ""

    var nextChar: char
    while nextChar != '\n':
      nextChar = engine.stdout.readChar

      result.add nextChar

  let line = engine.stdout.readLine

  when defined trace: debug "engine.received", line=line

  getMessage(line)

proc send(engine: ChessEngine, msg: GuiMessage) =
  let line = $msg

  when defined trace: debug "engine.sent", line=line

  engine.stdin.write line
  engine.stdin.flush()

iterator waitFor*(engine: ChessEngine, kind: EngineMessageKind): EngineMessage =
  var msg = none(EngineMessage)

  while msg.isNone() or msg.get.kind != kind:
    msg = some(engine.receive)

    yield msg.get()

proc `[]`*(e: ChessEngine, name: string): Option[EngineOption] =
  for opt in e.options:
    if opt.name == name: return opt.some

proc downloadEngine(path: string) =
  let client = newHttpClient()

  let
    releasesData = client.getContent("https://api.github.com/repos/ianfab/Fairy-Stockfish/releases/latest")
    releases = parseJson(releasesData)

  var targetName: string

  when defined(Linux):
    targetName = "fairy-stockfish-largeboard_x86-64"
  elif defined(Windows):
    targetName = "fairy-stockfish-largeboard_x86-64.exe"
  else:
    {.fatal: "Can't find engine for this platform".}

  for asset in releases["assets"].items():
    if asset["name"].getStr() == targetName:
      client.downloadFile(asset["browser_download_url"].getStr, path)
      break

  when defined Linux:
    let newFlags = int chmod(path.cstring, posix.Mode(0o500))

    if newFlags != 0:
      raise OSError.newException("Can't change engine flags")

proc newChessEngine*(filepath: string): ChessEngine =
  new result

  if not os.fileExists(filepath): downloadEngine(filepath)

  let program = startProcess(filepath, options={poDaemon})

  result.stdin = program.inputStream
  result.stdout = program. peekableOutputStream
  result.stderr = program. peekableErrorStream

  result.send GuiMessage(kind: gmkUci)

  for msg in result.waitFor(emkUciOk):
    if msg.kind == emkOption:
      result.options.add(msg.option)

  result.send GuiMessage(kind: gmkIsReady)

  for m in result.waitFor(emkReadyOk): discard

iterator search*(engine: ChessEngine, pos, limit: GuiMessage, game_id: string): EngineMessage {.inline.} =
  if pos.kind != gmkPosition or limit.kind != gmkGo:
    raise ValueError.newException("Invalid kind of pos or limit")

  if game_id != engine.game_id:
    engine.send GuiMessage(kind: gmkUciNewGame)
    engine.game_id = game_id

  for option in engine.options:
    if not option.isDefault():
      engine.send GuiMessage(kind: gmkSetOption, name: option.name, value: some($option))

  engine.send pos
  engine.send limit

  for m in engine.waitFor(emkBestMove):
    yield m

proc query*(engine: ChessEngine, state: GameState, vars: EvalResult): EngineMessage =
  let
    pos = GuiMessage(kind: gmkPosition, moves: state.moves)
    limit = GuiMessage(kind: gmkGo, movetime: some(vars.thinktime))

  block elo:
    let limitStrength = engine["UCI_LimitStrength"]

    if limitStrength.isSome:
      get(engine["UCI_LimitStrength"]).check = true

    let uciElo = engine["UCI_Elo"]
    if uciElo.isSome:
      get(uciElo).spin = math.clamp(int(vars.elo), get(uciElo).min..get(uciElo).max)

  var best: EngineMessage
  for msg in engine.search(pos, limit, game_id=state.info.id):
    if msg.kind == emkInfo:
      let info = msg.info

      engine.feedback.add info

      # await fs.sendInfo(msg)
      # TODO: Score report

      if info.score.isSome and info.score.get.kind == eskCp:
        let
          score = info.score.get
          val = if score.value.isSome: score.value.get else: 0

        if val > 0:
          state.score = val
        elif val < 0:
          state.enemyScore = val

    elif msg.kind == emkBestMove:
      best = msg

  return best

proc feedback*(engine: ChessEngine): seq[EngineInfo] = 
  result = deepCopy(engine.feedback)
  engine.feedback.setLen 0
