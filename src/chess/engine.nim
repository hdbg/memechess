import std/[osproc, streams, strutils, options]
import chronicles
import uci

type
  EngineOptionKind* = enum
    eokCheck,
    eokSpin,
    eokCombo,
    eokButton,
    eokString

  ChessEngine* = ref object
    program: Process
    stdin, stdout, stderr: Stream

    game_id: string

    options*: seq[EngineOption]

proc receive(engine: ChessEngine): EngineMessage =
  when false:
    result = ""

    var nextChar: char
    while nextChar != '\n':
      nextChar = engine.stdout.readChar

      result.add nextChar

  let line = engine.stdout.readLine

  debug "engine.received", line=line

  getMessage(line)

proc send(engine: ChessEngine, msg: GuiMessage) =
  let line = $msg

  debug "engine.sent", line=line

  engine.stdin.write line
  engine.stdin.flush()

proc send(engine: ChessEngine, kind: GuiMessageKind) =
  engine.send GuiMessage(kind: kind)

iterator waitFor*(engine: ChessEngine, kind: EngineMessageKind): EngineMessage =
  var msg = none(EngineMessage)

  while msg.isNone() or msg.get.kind != kind:
    msg = some(engine.receive)

    debug "msg.kind", k = msg.get.kind

    yield msg.get()

iterator search*(engine: ChessEngine, pos, limit: GuiMessage, game_id: string): EngineMessage =

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

proc newChessEngine*(filepath: string): ChessEngine =
  new result

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

proc close*(engine: ChessEngine) =
  engine.send gmkQuit
  engine.program.terminate()

