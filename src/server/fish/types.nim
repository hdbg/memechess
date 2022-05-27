import shared/proto
import std/options

type
  FishMode* = enum fmOff, fmAdvisor, fmLegit, fmRage
  RunnableMode*  = fmLegit..fmRage

  EvalVars* = object
    myScore*, enemyScore*: int
    myTime*, enemyTime*: float
    ply*: uint

  EvalResult* = object
    delay*, elo*, thinktime*: uint
    premove*: bool

  GameState* = ref object
    info*: GameStart

    moves*: seq[string]
    ply*: uint
    clock*: Clock

    score*: int
    enemyScore*: int

func initGameState*(start: GameStart): GameState =
  result.info = start

  for step in start.steps:
    if step.uci.isSome:
      result.moves.add step.uci.get

  if start.steps.len > 0:
    let lastStep = start.steps[start.steps.high]
    result.ply = lastStep.ply

    if lastStep.clock.isSome:
      result.clock = lastStep.clock.get

func canMove*(state: GameState): bool =
  let nextToMove: Side = if len(state.moves) mod 2 == 0: Side.csWhite else: Side.csBlack
  result = nextToMove == state.info.side

func getPlayerTime*(state: GameState): float =
  if state.info.side == Side.csWhite: return state.clock.white
  state.clock.black

func getEnemyTime*(state: GameState): float =
  if state.info.side == Side.csBlack: return state.clock.white
  state.clock.black

func initEvalVars*(state: GameState): EvalVars =
  result.myScore = state.score
  result.enemyScore = state.enemyScore

  result.myTime = state.getPlayerTime
  result.enemyTime = state.getEnemyTime
