import std/[strutils, options, parseutils, tables, strformat, macros]

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
    kind*: EngineScoreKind
    value*: Option[int]

  EngineOption* = ref object
    name*: string
    case kind*: EngineOptionKind
    of eokCheck:
      check*, checkDefault: bool
    of eokSpin:
      min*, max*, spin*, spinDefault: int
    of eokCombo:
      combo*, comboDefault*: string
      values: seq[string]
    of eokString:
      str, strDefault*: string
    else: discard

  EngineInfo* = object
    depth*, seldepth*, nodes*: Option[uint]
    currmovenumber*, hashfull*, nps*: Option[uint]
    tbhits*, sbhits*, cpuload*: Option[uint]

    time*: Option[float]
    refutation*, pv*: Option[seq[string]]
    multipv*: Option[uint]

    score*: Option[EngineScore]

    currmove*, str*: Option[string]

  EngineMessage* = object
    case kind*: EngineMessageKind
    of emkId:
      name*, author*: Option[string]
    of emkBestMove:
      bestmove*: string
      ponder*: Option[string]
    of emkInfo:
      info*: EngineInfo
    of emkOption:
      option*: EngineOption
    else: discard

{.push inline, discardable.}
proc skipIdent(ident, msg: string): int =
  let match = msg.find(ident)
  if match == -1: return -1

  result = match + ident.len + 1 # last +1 for whitespace

  if result > msg.high:
    return -1

using
  msg: string
  name: string

proc get(name, msg; target: var string, space: bool = false): int =
  # if (msg.find(name) + name.len + 1) == msg.high: return -1

  let identEnd = skipIdent(name, msg)

  if identEnd == -1: return -1

  var delims = {'\n'}
  if space: delims.incl ' '

  parseUntil(msg, target, delims, start=identEnd)

proc getStrOption(name, msg; target: var Option[string], space: bool = false) =
  var s: string
  if get(name, msg, s, space) == -1:
    target = none(string)
  else:
    target = some(s)

proc getOption[T](name, msg; target: var Option[T]) =
  var val: T
  if get(name, msg, val) == -1:
    target = none(T)
  else:
    target = some(val)

template createGet(typing: typedesc, parser: typed) =
  proc get(name, msg: string, target: var typing): int =
    let index = skipIdent(name, msg)
    if index == -1: return -1

    when typing isnot bool:
      parser(msg, target, start=index)
    else:
      var s: string
      get(name, msg, s, true)
      target = parser(s)

createGet int, parseInt
createGet uint, parseUInt
createGet float, parseFloat
createGet bool, parseBool

{.pop.}

# Engine-to-gui
proc parseInfo(msg: string): EngineMessage =
  result = EngineMessage(kind: emkInfo)

  var info: EngineInfo

  getOption "depth", msg, info.depth
  getOption "seldepth", msg, info.seldepth

  getOption "time", msg, info.time
  getOption "nodes", msg, info.nodes
  getOption "multipv", msg, info.multipv
  getOption "currmove", msg, info.currmove
  getOption "currmovenumber", msg, info.currmovenumber
  getOption "hashfull", msg, info.hashfull
  getOption "nps", msg, info.nps
  getOption "tbhits", msg, info.tbhits
  getOption "sbhits", msg, info.sbhits
  getOption "cpuload", msg, info.cpuload
  getStrOption "string", msg, info.str

  var rawPv: Option[string]
  getStrOption " pv", msg, rawPv # otherwise triggers on "multipv"

  if rawPv.isSome:
    info.pv = some(rawPv.get.split())

  if "score" in msg:
    var scoreKind: string
    get "score", msg, scoreKind, true

    info.score = some(EngineScore())

    case scoreKind
    of "cp":
      info.score.get.kind = eskCp
      getOption "cp", msg, info.score.get.value
    of "mate":
      info.score.get.kind = eskMate
      getOption "mate", msg, info.score.get.value
    of "lowerbound":
      info.score.get.kind = eskLowerbound
    of "upperbound":
      info.score.get.kind = eskUpperbound

  result.info = move(info)

proc parseOption(msg: string): EngineMessage =
  result = EngineMessage(kind: emkOption)

  var kind: string
  get "type", msg, kind, true

  const strToKind = {"check": eokCheck,
                     "spin": eokSpin,
                     "combo": eokCombo,
                     "button": eokButton,
                     "string": eokString
                    }.toTable

  var option = EngineOption(kind:strToKind[kind])

  # get "name", msg, option.name, true

  block parseName:
    let ind = msg.find("name") + "name".len + 1
    discard parseUntil(msg, option.name, " type", start=ind)

  case option.kind
  of eokCheck:
    get "default", msg, option.check
    option.checkDefault = option.check
  of eokSpin:
    get "default", msg, option.spin
    get "min", msg, option.min
    get "max", msg, option.max

    option.spinDefault = option.spin
  of eokString:
    get "default", msg, option.str
    option.strDefault = option.str
  of eokCombo:
    get "default", msg, option.combo, true

    option.comboDefault = option.combo

    let splitted: seq[string] = msg.split(' ')

    for i in splitted.low()..splitted.high():
      if (splitted[i]) == "var":
        option.values.add splitted[i+1]

  else: discard

  result.option = move(option)

proc parseBestMove(msg: string): EngineMessage =
  result = EngineMessage(kind: emkBestMove)

  get("bestmove", msg, result.bestmove, space=true)
  getStrOption("ponder", msg, result.ponder, space=true)

proc getMessage*(msg: string): EngineMessage =
  const
    funcTable = {"bestmove": parseBestMove, "option": parseOption, "info": parseInfo}.toTable
    shortTable = {"uciok": emkUciOk, "readyok": emkReadyOk}.toTable

  for (prefix, callback) in funcTable.pairs():
    if msg.startswith prefix:
      return callback(msg)

  for (prefix, kind) in shortTable.pairs():
    if msg.startswith prefix:
      return EngineMessage(kind:kind)

proc isDefault*(option: EngineOption): bool =
  case option.kind
  of eokCombo:
    return option.combo == option.comboDefault
  of eokSpin:
    return option.spin == option.spinDefault
  of eokString:
    return option.str == option.strDefault
  of eokCheck:
    return option.check == option.checkDefault
  of eokButton: return true

proc resetDefault*(option: var EngineOption) =
  case option.kind
  of eokCombo:
    option.combo = option.comboDefault
  of eokSpin:
    option.spin = option.spinDefault
  of eokString:
    option.str = option.strDefault
  of eokCheck:
    option.check = option.checkDefault
  of eokButton: discard

proc `$`*(option: EngineOption): string =
  case option.kind
  of eokCombo:
    return $option.combo
  of eokSpin:
    return $option.spin
  of eokString:
    return option.str
  of eokCheck:
    return $option.check
  of eokButton: return ""

# Gui-to-engine

type
  GuiMessageKind* = enum
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

  GuiMessage* = object
    case kind*: GuiMessageKind
    of gmkDebug:
      debug*: bool
    of gmkSetOption:
      name*: string
      value*: Option[string]
    of gmkPosition:
      fen*: Option[string]
      moves*: seq[string]
    of gmkGo:
      searchmoves*: seq[string]
      wtime*, btime*: Option[uint] # milis
      winc*, binc*: Option[uint]
      movestogo*: uint # No option cause counts only if > 0

      depth*, nodes*, mate*: Option[uint]
      movetime*: Option[uint]

      # Add infinite switch here
    else: discard

proc serializeGo(msg: GuiMessage): string =
  result = "go"

  macro optionInsert(name: untyped) =
    var ident = name.strVal

    result = quote do:
      if msg.`name`.isSome:
        result.add(" " & `ident` & " " & ($msg.`name`.get))

  # im sorry, this is ugly
  optionInsert wtime
  optionInsert btime
  optionInsert winc
  optionInsert binc

  optionInsert depth
  optionInsert nodes
  optionInsert mate
  optionInsert movetime

  if msg.movestogo > 0:
    result.add &" movestogo {$msg.movestogo}"

  if msg.searchmoves.len > 0:
    result.add " searchmoves"

    for move in msg.searchmoves:
      result.add " " & move

proc `$`*(msg: GuiMessage): string =
  result = ""

  case msg.kind
  of gmkDebug:
    result = "debug " & $msg.debug
  of gmkSetOption:
    result = "setoption name " & msg.name
    if msg.value.isSome and msg.value.get != "":
      result.add " value " & msg.value.get

  of gmkPosition:
    result = "position"

    if msg.fen.isSome:
      result.add " fen " & msg.fen.get
    else:
      result.add " startpos"

    if unlikely(msg.moves.len > 0):
      result.add " moves"           # no whitespace in the end, because every added move adds it
      for move in msg.moves:
        result.add &" {move}"
  of gmkGo:
    result = serializeGo(msg)
  of gmkUci: result = "uci"
  of gmkIsReady: result = "isready"
  of gmkStop: result = "stop"
  of gmkPonderHit: result = "ponderhit"
  of gmkQuit: result = "quit"
  of gmkUciNewGame: result = "ucinewgame"
  # of gmkRegister:
  else: discard

  result.add '\n'


