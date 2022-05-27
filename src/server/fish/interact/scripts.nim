import server/fish/types
import server/fish/chess/engine as ce
import shared/proto

import chronicles
import nimscripter

import std/[os, options, macros, tables, md5]

const
  scriptsPath = "mchess" / "scripts"
  stdPath = "mchess" / "stdlib"

const stdFiles = block:
  var result = initTable[string, tuple[hash, content: string]]()

  let foundPath = parentDir(currentSourcePath()) / "stdlib"

  for dir in walkDirRec(foundPath, checkDir = true):
    let
      relative = relativePath(dir, foundPath)
      content = staticRead(dir)

    result[relative] = (
      hash: content.getMD5,
      content: content
    )

  result

# Scripts types
type
  Optionable[T] = ref object
    val: T
    has: bool

converter toOption[T](p: Optionable[T]): Option[T] =
  if p.isSome:
    result = options.some(p.val)
  else:
    result = options.none[T]()

# Scripts

type
  ScriptsManager* = ref object
    engine: ChessEngine
    scripts: seq[Interpreter]

proc deployStd() =
  discard existsOrCreateDir stdPath

  for (filepath, fileData) in stdFiles.pairs():
    let realPath = stdPath / filepath

    for d in filepath.parentDirs(fromRoot=true, inclusive=false):
      discard existsOrCreateDir(stdPath / d)

    if not fileExists(realPath):
      writeFile(realPath, fileData.content)
    else:
      let fileHash = getMD5(readFile(realPath))

      if fileHash != fileData.hash:
        error "corrupted", file=filepath
        writeFile(realPath, fileData.content)

proc newScriptsManager*(engine: ChessEngine): ScriptsManager =
  discard existsOrCreateDir(scriptsPath)

  result = new ScriptsManager

  result.engine = engine
  result.scripts = @[]

  deployStd()

  exportTo(
    memeScript,

    EvalResult,
    EvalVars,
    # ChessEngine,
    # EngineOption,
    Optionable,

    Clock,
    Variant,
    Time,
    Side,

    Step,
    GameStart,
    GameState,
  )

  exportCode(memeScript):
    proc isSome[T](op: Optionable[T]): bool = op.has
    proc isNone[T](op: Optionable[T]): bool = not op.has

    proc some[T](val: T): Optionable[T] = Optionable[T](value: val, has: true)
    proc none[T](): Optionable[T] = Optionable[T](has: false)
    proc none(T: typedesc): Optionable[T] = Optionable[T](has: false)

  # callbacks
  addCallable(memeScript):
    proc onGameStart(data: GameStart)
    proc onStep(step: Step)
    proc onEngineFire(state: GameState, vars: EvalVars): tuple[has: bool, val: EvalResult]
    # onGameEnd

  const scriptSpace = implNimScriptModule(memeScript)

  for s in walkFiles(scriptsPath / "*.nims"):
    let scriptCode = readFile(s)

    var scriptUnit = loadScript(
      scriptCode.NimScriptFile,
      scriptSpace,
      modules = ["options"],
      stdPath = stdPath
    )

    if scriptUnit.isSome:
      result.scripts.add move(scriptUnit.get)
      debug "script.loaded", path=s

using mng: ScriptsManager

proc fire*(mng; start: GameStart) =
  for s in mng.scripts: s.invoke(onGameStart, start)

proc fire*(mng; step: Step) =
  for s in mng.scripts: s.invoke(onStep, step)

proc eval*(mng; state: GameState, vars: EvalVars): Option[EvalResult] =
  for s in mng.scripts:
    let r = s.invoke(onEngineFire, state, vars, returnType = tuple[has: bool, val: EvalResult])
    if r.has:
      return options.some(r.val)
