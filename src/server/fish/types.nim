import shared/proto
import std/[options, math]

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
    clock*: Option[Clock]

    score*: int
    enemyScore*: int

func initGameState*(start: GameStart): GameState =
  result = GameState(info: start)

  for step in start.steps:
    if step.uci.isSome:
      result.moves.add step.uci.get

  # No need
  if isSome start.clock:
    result.clock = start.clock

  if start.steps.len > 0:
    let lastStep = start.steps[start.steps.high]
    result.ply = lastStep.ply

    if lastStep.clock.isSome:
      result.clock = lastStep.clock

func canMove*(state: GameState): bool =
  let nextToMove: Side = if len(state.moves) mod 2 == 0: Side.csWhite else: Side.csBlack
  result = nextToMove == state.info.side

func playerTime*(state: GameState): float =
  if state.info.side == Side.csWhite: return get(state.clock).white
  get(state.clock).black

func enemyTime*(state: GameState): float =
  if state.info.side == Side.csBlack: return get(state.clock).white
  get(state.clock).black

func whiteTime*(state: GameState): float =
  get(state.clock).white

func blackTime*(state: GameState): float =
  get(state.clock).white

func millis*(f: float): uint =
  uint trunc(f * 1000)

func initEvalVars*(state: GameState): EvalVars =
  result.myScore = state.score
  result.enemyScore = state.enemyScore

  result.myTime = state.playerTime
  result.enemyTime = state.enemyTime
