import std/[strutils, options, pegs, parseutils]

type
  EngineMessageKind* = enum
    emkId
    emkUciOk
    emkReadyOk
    emkBestMove
    emkInfo
    emkOption

  EngineScoreKind* = enum eskCp, eskMate, eskLowerbound, eskUpperbound
  EngineOptionKind* = enum eokCheck, eokSpin, eokCombo, eokButton, eokString

  EngineScore* = object
    kind: EngineScoreKind
    value: int

  EngineOption* = object
    name: string
    case kind: EngineOptionKind
    of eokCheck:
      check: bool
    of eokSpin:
      min, max, spin: int
    of eokCombo:
      combo: string
      values: seq[string]
    of eokString:
      str: string
    of eokButton:
      button: string

  EngineInfo* = object
    depth, seldepth, nodes: Option[uint]
    currmovenumber, hashfull, nps: Option[uint]
    tbhits, sbhits, cpuload: Option[uint]

    time: Option[float]
    refutation, pv: Option[seq[string]]
    multipv: Option[uint]

    score: EngineScore

    currmove, str: Option[string]


  EngineMessage* = object
    case kind: EngineMessageKind
    of emkId:
      name, author: Option[string]
    of emkBestMove:
      bestmove: string
      ponder: Option[string]
    of emkInfo:
      info: EngineInfo
    of emkOption:
      option: EngineOption
    else: discard

proc skipIdent(ident, msg: string): int =
  let match = msg.find(name)
  if match == -1: return -1
  let valueStart = match + name.len + 1 # last +1 for whitespace

  if valueStart > msg.high:
    raise ValueError("Invalid index")

proc get(name, msg: string, target: var int) {.inline.} =
  parseInt(msg, target, start=skipIdent(name, msg))

proc get(name, msg: string, target: var uint) {.inline.} =
  parseUInt(msg, target, start=skipIdent(name, msg))

proc get(name, msg: string, target: var float) {.inline.} =
  parseFloat(msg, target, start=skipIdent(name, msg))

proc get(name, msg: string, target: var string) {.inline.} =
  let identEnd = skipIdent(name, msg)
  parseUntil(msg, target, '\n')

proc get[T](name, msg: string, target: var Option[T]) {.inline.} =
  var val: T
  get(name, msg, val)
  target = some(val)

# Low-level api
proc parseInfo(msg: string): EngineMessage =
  result = EngineMessage(kind: emkInfo)

  var info: EngineInfo

  get "depth", msg, info.depth
  get "seldepth", msg, info.seldepth

  get "time", msg, info.time
  get "nodes", msg, info.nodes
  get "multipv", msg, info.multipv
  get "currmove", msg, info.currmove
  get "currmovenumber", msg, info.currmovenumber
  get "hashfull", msg, info.hashfull
  get "nps", msg, info.nps
  get "tbhits", msg, info.tbhits
  get "sbhits", msg, info.sbhits
  get "cpuload", msg, info.cpuload
  #get "string", msg, info.str

  var rawPv: string
  get "pv", msg, rawPv

  info.pv = rawPv.split()


proc getMessage*(msg: string): EngineMessage = discard
