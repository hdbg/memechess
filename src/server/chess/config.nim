import mathexpr
import shared/proto
import std/[options, json, algorithm, strformat, os, enumutils, tables]
import chronicles
import parsetoml

import std/marshal

const
  defaultConfig = """
name = "Memechess Bullet Rage"
kind = "ckRage"
time = ["ctUltrabullet", "ctBullet"]

[[events]]
condition = {lhs = "my_time + 10.0", op = "<=" , rhs = "200"} # <= - greater or equals
delay = "(2.0 * enemy_time) / 2.0"
elo = "1800.0"
thinktime = "100.0" # in ms, no floating point values allowed

[[events]]
condition = {lhs = "my_score", op = ">", rhs = "500"}
delay = "100.0"
elo = "500 ** 3"
thinktime = "50.0"
"""
  configPath = "memechess" / "configs"

type
  Expression = string

  Condition = object
    lhs, rhs: Expression
    op: string

  Event = object
    condition: Condition
    delay, elo, thinktime: Expression

  ConfigKind* = enum ckRage, ckLegit, ckAdvisor

  Config* = ref object
    name*: string
    kind*: ConfigKind
    time*: seq[ChessTime]

    events: seq[Event]

  ConfigManager* = ref object
    configs*: seq[Config]

  EvalVars* = object
    my_score*, enemy_score*: int
    my_time*, enemy_time*: uint

  EvalResult* = object
    delay*, elo*, thinktime*: uint

proc getStrTimesTable(): Table[string, ChessTime] {.compileTime.} =
  for t in ChessTime.items():
    result[symbolName(t)] = t

template invalid(desc: string) =
  mixin filepath
  raise ValueError.newException(&"Invalid config '{filepath}': " & desc)

proc validate(c: Config, filepath: string) =
  proc empty[T](s: T): bool = s.len < 1

  if c.name.empty: invalid("No config name specified")
  if c.time.empty: invalid("No times specified")

  for event_id in 0..high(c.events):
    let event = c.events[event_id]

    if event.delay.empty: invalid(&"Event [{$event_id}] has no delay expression")
    if event.elo.empty: invalid(&"Event [{$event_id}] has no elo expression")
    if event.thinktime.empty: invalid(&"Event [{$event_id}] has no thinktime expression")

    if event.condition.lhs.empty:
      invalid(&"Event [{$event_id}] condition lhs has no expression")
    if event.condition.rhs.empty:
      invalid(&"Event [{$event_id}] condition rhs has no expression")

    const validOps = ["<", ">", "==", "<=", ">=", "!="]
    if event.condition.op notin validOps:
      invalid(&"Event [{$event_id}] condition contains invalid operator '{event.condition.op}', valid ones: {$validOps}")

proc newConfig(filepath: string): Config =
  let
    fileData = readFile(filepath)
    rawToml = parsetoml.parseString(fileData)

  new result

  result.name = rawToml["name"].getStr

  block setKind:
    for cKind in ConfigKind.items():
      if symbolName(cKind) == rawToml["kind"].getStr():
        result.kind = cKind
        break setKind

    invalid("No config kind specified")

  block setTimes:
    const strTime = getStrTimesTable()

    for rawTime in rawToml["time"].getElems():
      if rawTime.kind != TomlValueKind.String: invalid("Invalid time type")
      let rawTimeName = rawTime.getStr()
      if not strTime.hasKey(rawTimeName): invalid(&"Time {rawTimeName} not found")

      result.time.add strTime[rawTimeName]

  block parseEvents:
    const
      tStr = TomlValueKind.String
      tTable = TomlValueKind.Table

    proc parseCondition(node: TomlValueRef): Condition =
      const requiredKeys = ["lhs", "rhs", "op"]
      for k in requiredKeys:
        if not node.hasKey(k): invalid(&"Condition doesn't have attribute '{k}'")
        if node[k].kind != tStr: invalid(&"Key '{k}' is not String")

      result.lhs = node["lhs"].getStr
      result.rhs = node["rhs"].getStr
      result.op = node["op"].getStr

    for rawEvent in rawToml["events"].getElems():
      var newEvent = Event()

      if rawEvent.kind != TomlValueKind.Table: invalid("Malformed event section")

      const requiredKeys = {"condition": tTable, "elo": tStr, "delay": tStr,
          "thinktime": tStr}.toTable
      for k, t in requiredKeys.pairs():
        if not rawEvent.hasKey(k): invalid(&"Event doesn't have attribute '{k}'")
        if rawEvent[k].kind != t: invalid(&"Key '{k}' is not {symbolName(t)}")

      newEvent.elo = rawEvent["elo"].getStr
      newEvent.delay = rawEvent["delay"].getStr
      newEvent.thinktime = rawEvent["thinktime"].getStr

      newEvent.condition = parseCondition(rawEvent["condition"])

      result.events.add newEvent

  result.validate filepath

proc newConfigManager*(): ConfigManager =
  result = new ConfigManager

  for c in walkFiles(configPath / "*.toml"):
    debug "config.load", path = c
    result.configs.add newConfig(c)

  if result.configs.len < 1:
    warn "config.not_found"

    let newPath = configPath / "default.toml"

    var fileHandle = open(newPath, fmWrite)
    fileHandle.write(defaultConfig)
    fileHandle.close()

    result.configs.add(newConfig(newPath))

proc eval(c: Condition, e: Evaluator): bool =
  let
    lhs = e.eval(c.lhs)
    rhs = e.eval(c.rhs)

  case c.op
  of "<": return lhs < rhs
  of "<=": return lhs <= rhs
  of ">": return lhs > rhs
  of ">=": return lhs >= rhs
  of "==": return lhs == rhs
  of "!=": return lhs != rhs
  else: discard

proc eval(event: Event, e: Evaluator): EvalResult =
  result.delay = e.eval(event.delay).uint
  result.elo = e.eval(event.elo).uint
  result.thinktime = e.eval(event.thinktime).uint

proc eval*(c: Config, vars: EvalVars): EvalResult =
  let evaluator = newEvaluator()

  evaluator.addVar("my_time", vars.my_time.float)
  evaluator.addVar("enemy_time", vars.enemy_time.float)
  evaluator.addVar("my_score", vars.my_score.float)
  evaluator.addVar("enemy_score", vars.enemy_score.float)

  var
    event: Event

  block findEvent:
    for e in c.events:
      if e.condition.eval(evaluator):
        event = e
        break findEvent

    raise ValueError.newException(&"Can't activate config {c.name}'")

  event.eval(evaluator)

