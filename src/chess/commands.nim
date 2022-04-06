import std/[tables, strutils, parseopt]

export parseopt.CmdLineKind
export tables.`[]`

type
  CommandCallback = proc(ctx: CommandContext)

  CommandContext* = ref object
    options*: Table[string, string]
    arguments*: Table[string, string]

  ParameterKind* = enum pkString, pkBool, pkInt, pkUInt, pkFloat

  CommandParameter* = object
    name*: string
    variant*: CmdLineKind
    kind*: ParameterKind

  TerminalCommand = object
    name*: string
    params: seq[CommandParameter]
    callback: proc(ctx: CommandContext)

  CommandDispatcher* = ref object
    commands: seq[TerminalCommand]


proc addCommand*(cd: CommandDispatcher, name: string, params: seq[CommandParameter], cb: CommandCallback) =
  var command = TerminalCommand(name:name, params:params, callback:cb)
  cd.commands.add command

template onCommand*(cd: CommandDispatcher, name: string, params: seq[CommandParameter], body: untyped) =
  proc cb(data: CommandContext) =
    let ctx {.inject.} = data
    body

  cd.addCommand(name, params, cb)

proc dispatch*(cd: CommandDispatcher, cmdline: string) =
  for command in cd.commands:
    if not cmdline.startsWith(command.name): continue

    var cmd = cmdline[command.name.len + 1..1.BackwardsIndex]

    var
      noValShort: set[char]
      noValLong: seq[string]

    for p in command.params:
      if p.kind == pkBool:
        case p.variant
        of cmdShortOption: noValShort.incl p.name[0]
        of cmdLongOption: noValLong.add p.name
        else: discard

    var opts = initOptParser(cmd, noValShort, noValLong)

    var ctx = CommandContext()

    var
      lastArgName = 0
      argNames: seq[string]

    for param in command.params:
      if param.variant == cmdArgument:
        argNames.add param.name

    for (kind, key, val) in opts.getopt():
      case kind
      of cmdLongOption, cmdShortOption:
        if key in noValLong or key[0] in noValShort:
          ctx.options[key] = $true
        else: ctx.options[key] = val
      of cmdArgument:
        ctx.arguments[argNames[lastArgName]] = key
        lastArgName.inc
      else: discard

    command.callback(ctx)

    return

when false:
  proc getOption[T](ctx: CommandContext, name: string): T =
    let raw = ctx.options[name]

    case $T
    of "string": return raw
    of "int": return parseInt(raw)
    of "uint": return parseUInt(raw)
    of "float": return parseFloat(raw)
    else: return T(raw)

  proc getArgument[T](ctx: CommandContext, name: string): T =
    let raw = ctx.arguments[name]

    case $T
    of "string": return raw
    of "int": return parseInt(raw)
    of "uint": return parseUInt(raw)
    of "float": return parseFloat(raw)
    else: return T(raw)

proc newCommandDispatcher*(): CommandDispatcher = new result
