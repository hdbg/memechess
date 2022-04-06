import std/[strutils, options, parseutils, tables, pegs, strformat]

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

proc get(name, msg: string, target: var bool) {.inline.} =
  parseBool(msg, target, start=skipIdent(name, msg))

proc get(name, msg: string, target: var string, space: bool = false) {.inline.} =
  let identEnd = skipIdent(name, msg)

  var delims = {'\n'}
  if space: delims.incl ' '

  parseUntil(msg, target, delims)

proc get[T](name, msg: string, target: var Option[T]) {.inline.} =
  var val: T
  get(name, msg, val)
  target = some(val)

# Engine-to-gui
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

  result.info = move(info)

proc parseOption(msg: string): EngineMessage =
  result = EngineMessage(kind: emkOption)

  var option: EngineOption

  get "name", msg, option.name, true

  var oType: string
  get "type", msg, oType, true

  const strToKind = {"check": eokCheck,
                     "spin": eokSpin,
                     "combo": eokCombo,
                     "button": eokButton,
                     "string": eokString
                    }.toTable

  option.kind = strToKind[oType]

  case option.kind
  of eokCheck:
    get "default", msg, option.check
  of eokSpin:
    get "default", msg, option.spin
    get "min", msg, option.min
    get "max", msg, option.max
  of eokString:
    get "default", msg, option.str
  of eokCombo:
    get "default", msg, option.combo, true
    const varSearch = peg"var {\w+}"
    match(msg, varSearch, option.values)
  else: discard

  result.option = move(option)

proc getMessage*(msg: string): EngineMessage = discard

# Gui-to-engine

type
  GuiMessageKind = enum
    gmkUci
    gmkDebug
    gmkIsReady
    gmkSetOption
    gmkRegister
    gmkUciNewGame
    gmkPosition
    gmkGo
    gmkStop
    gmkPonderHit
    gmkQuit

  GuiMessage = object
    case kind: GuiMessageKind
    of gmkDebug:
      debug: bool
    of gmkSetOption:
      name: string
      value: Option[string]
    of gmkPosition:
      fen: Option[string]
      moves: seq[string]
    of gmkGo:
      searchmoves: seq[string]
      wtime, btime: Option[float]
      winc, binc: Option[uint]
      movestogo: uint # No option cause counts only if > 0

      depth, nodes, mate: Option[uint]
      movetime: Option[uint]

      # Add infinite switch here
    else: discard

proc `$`*(msg: GuiMessage): string =
  result = ""

  case msg.kind
  of gmkDebug:
    result = "debug " & $msg.debug
  of gmkSetOption:
    result = "setoption name " & msg.name
    if value.isSome:
      result.add " value " & msg.value.get

  of gmkPosition:
    result = "position "

    if msg.fen.isSome:
      result.add " fen " & msg.fen.get
    else:
      result.add " startpos"

    if unlikely(msg.moves.len > 0):
      result.add " moves"           # no whitespace in the end, because every added move adds it
      for move in msg.moves:
        result.add &" {move} "
  of gmkGo:
    template optionInsert(name: untyped, uciName: Option[string]) =
      let
        value = $msg.name
        realName = if uciName.isSome: uciName.get else: &"{name}" # sorry for COSTYL

      result.add &" {realName} {value}"

    # im sorry, this is ugly
    optionInsert wtime
    optionInsert btime
    optionInsert winc
    optionInsert binc
    optionInsert movestogo
    optionInsert depth
    optionInsert nodes
    optionInsert mate
    optionInsert movetime

    if msg.searchmoves.len > 0:
      result,add " searchmoves"

      for mov in searchmoves:
        result.add " " & move

when false:
  proc uci(): string = "uci"
  proc debug(mode: bool): string = "debug " & if mode: "on" else: "off"
  proc isReady(): string = "isready"
  proc setOption(name: string, value: Option[string]): string =
    if value.isSome:
      return &"setoption name {name} value {value}"
    else:
      return "setoption name " & value

  # proc register

  proc uciNewGame(): string = "ucinewgame"
