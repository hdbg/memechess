import std/[osproc, streams, strutils]
import chronicles

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

proc getMessage(engine: ChessEngine): string =
  when false:
    result = ""

    var nextChar: char
    while nextChar != '\n':
      nextChar = engine.stdout.readChar

      result.add nextChar

  engine.stdout.readLine

proc sendMessage(engine: ChessEngine, msg: string) =
  if not msg.endswith('\n'):
      raise ValueError.newException("Message doesn't end with \\n'")

  engine.stdin.write msg.strip()

proc newChessEngine*(filepath: string) =
  new result

  let program = startProcess(filepath, options={poDaemon})

  result.stdin = program.inputStream
  result.stdout = program.outputStream
  result.stderr = program.errorStream


