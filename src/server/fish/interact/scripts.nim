import server/fish/types
import server/fish/chess/engine as ce
import server/fish/chess/uci
import shared/proto

import chronicles

import nimscripter

import std/[os, options, macros]

const scriptsPath = "mchess" / "scripts"

# Scripts types

type
  PseudoOption[T] = ref object
    val: T
    has: bool

proc some[T](val: T): PseudoOption[T] =
  PseudoOption(val: move(val), has: true)

proc none[T](): PseudoOption[T] = PseudoOption[T](has: false)

proc isSome[T](op: PseudoOption[T]): bool = op.has
proc isNone[T](op: PseudoOption[T]): bool = not op.has

converter toOption[T](p: PseudoOption[T]): Option[T] =
  if p.isSome:
    result = options.some(p.val)
  else:
    result = option.none(T)

# Scripts

type
  ScriptsManager* = ref object
    engine: ChessEngine
    scripts: seq[Interpreter]

proc newScriptsManager*(engine: ChessEngine): ScriptsManager =
  result = new ScriptsManager

  result.engine = engine
  result.scripts = @[]

  exportTo(
    memeScript,
    EvalResult,
    EvalVars,
    # ChessEngine,
    # EngineOption,
    PseudoOption,

    Clock,
    Variant,
    Time,
    Side,

    Step,
    GameStart,
    GameState
  )

  # Procs
  exportTo(
    memeScript,

    some,
    none,
    isSome,
    isNone
  )

  # callbacks
  addCallable(memeScript):
    proc onGameStart(data: GameStart)
    proc onStep(step: Step)
    proc onEngineFire(state: GameState, vars: EvalVars): PseudoOption[EvalResult]
    # onGameEnd

  const scriptSpace = implNimScriptModule(memeScript)

  for s in walkFiles(scriptsPath / "*.nims"):
    let scriptCode = readFile(s)

    var scriptUnit = loadScript(scriptCode.NimScriptFile, scriptSpace, modules = ["options"])

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
    result =  s.invoke(onEngineFire, state, vars, returnType = PseudoOption[EvalResult])
    if result.isSome: return
