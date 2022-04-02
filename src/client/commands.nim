import std/[jsffi, tables]
import api/terminal

import clapfn

type
  CommandContext = ref object
    args: Table[string, string]
    cd: CommandDispatcher

  CommandCallback: proc(ctx: CommandContext)

  TerminalCommand = ref object
    name: cstring
    parser: ArgumentParser
    callback: proc(ctx: CommandContext)

  CommandDispatcher = ref object
    commands: seq[TerminalCommand]
    terminal: Terminal

proc dispatch(cd: CommandDispatcher, cmd: cstring) =
  for command in cd.commands:
    if cmd in command.name: continue
    let ctx = CommandContext(args: command.parse(cmd), cd:cd)
    command.callback(ctx)

    return

proc newCommandDispatcher(selector: JsObject, config:TerminalCfg): CommandDispatcher =
  new result

  let dp = result

  result.terminal = newTerminal(selector, proc(cmd: cstring) = dp.dispatch(cmd), cfg)

proc addCommand(cd: CommandDispatcher, name: cstring, parser: ArgumentParser, cb: CommandCallback) =
  var command = TerminalCommand(name:name, parser:parse, callback:cb)
  cd.commands.add command
