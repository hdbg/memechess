import mathexpr
import shared/proto
import std/[options, json, strformat, os, enumutils, tables, random]
import chronicles
import parsetoml
import "server/fish/types"

# Credits: Sanek
const
  defaultConfig = """
name = "UltraBullet Rage config"
kind = "fmRage"
time = ["ctUltrabullet"]

[[events]]
condition = {lhs = "ply", op = "<=", rhs = "2"} # debut (first move)
delay = "500.0 + random(600.0)"
elo = "2000"
thinktime = "100.0"

[[events]]
condition = {lhs = "enemy_time", op = ">=", rhs = "12.5"} # debut (first 2.5 seconds)
delay = "(random(20.0) + floor(random(2.0)) * random(100.0)) * (enemy_time - 11.5)"
elo = "1000"
thinktime = "100"

[[events]]
condition = {lhs = "my_time", op = "<", rhs = "1.24"}
delay = "max(1, random(100.0))"
elo = "max(1300, min(my_score, 2400))"
thinktime = "30.0"

[[events]]
condition = {lhs = "my_time", op = "<", rhs = "3.2"}
delay = "max(1, random(220.0))"
elo = "max(1300, min(my_score, 2400))"
thinktime = "50.0"

[[events]]
condition = {lhs = "my_time", op = "<", rhs = "7"}
delay = "300.0"
elo = "1000.0"
thinktime = "random(20.0) + floor(random(2.0)) * (random(1000.0))"

[[events]]
condition = {lhs = "my_time", op = ">", rhs = "enemy_time"}
delay = "400 + max(0, 1000.0 * ((my_time - enemy_time) - random(2.0) + 2))"
elo = "850.0"
thinktime = "100.0"

[[events]]
condition = {lhs = "my_time", op = "<", rhs = "enemy_time"}
delay = "floor(random(2.0)) * (random(600.0))"
elo = "950.0"
thinktime = "100 + max(20, 100 - enemy_time * 8)"

[[events]]
condition = {lhs = "0.0", op = "==", rhs = "0.0"}
delay = "0"
elo = "2000.0"
thinktime = "40.0"
"""
  configPath = "mchess" / "configs"

type
  Expression = string

  Condition = object
    lhs, rhs: Expression
    op: string

  Event = object
    condition: Condition
    delay, elo, thinktime: Expression

  Config* = ref object
    name*: string
    kind*: RunnableMode
    time*: seq[Time]

    events: seq[Event]

  ConfigManager* = ref object
    configs*: seq[Config]

proc getStrTimesTable(): Table[string, Time] {.compileTime.} =
  for t in Time.items():
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
    for cKind in FishMode.items():
      if symbolName(cKind) == rawToml["kind"].getStr():
        result.kind = cKind
        debug "config.kind", kind=symbolName(cKind), path=filepath
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
    warn "configs.not_found"

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

proc eval*(c: Config, vars: EvalVars): Option[EvalResult] =
  let evaluator = newEvaluator()

  evaluator.addVar("my_time", vars.my_time.float)
  evaluator.addVar("enemy_time", vars.enemy_time.float)
  evaluator.addVar("my_score", vars.my_score.float)
  evaluator.addVar("enemy_score", vars.enemy_score.float)
  evaluator.addVar("ply", vars.ply.float)

  evaluator.addFunc(
    name="random",
    argCount=1,
    fun = proc(args: seq[float]): float = rand(args[0])
  )

  var
    event: Event

  block findEvent:
    for event_id in 0..high(c.events):
      let e = c.events[event_id]

      if e.condition.eval(evaluator):
        event = e
        break findEvent

    return none(EvalResult)

  some(event.eval(evaluator))

proc eval*(mng: ConfigManager, state: GameState, vars: EvalVars, mode: FishMode): Option[EvalResult] =
  for config in mng.configs:
    if config.kind != mode: continue
    if state.info.time notin config.time: continue

    result = config.eval(vars)
    if result.isSome: return
