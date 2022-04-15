proc cmdChangeMode(fs: FishServer, ctx: CommandContext) {.async.} = discard

proc cmdReload(fs: FishServer) {.async.} =
  try:
    var cfgManager = newConfigManager()
    fs.configs = cfgManager

    fs.gameState.config = none(Config)

    await fs.echo("Configs reloaded.")

  except Exception as e:
    await fs.echo("[[b;#ec3829;]Configs reload error]")
    echo e.msg

proc cmdEngineReload(fs: FishServer) {.async.} =
  fs.engine = newChessEngine("engine.exe")
  await fs.echo("Engine reloaded.")

proc cmdHelp(fs: FishServer) {.async.} =
  await fs.echo(fs.commands.help())

proc cmdSetMode(fs: FishServer, ctx: CommandContext) {.async.} =
  var fishModes: Table[string, FishMode]
  for fm in FishMode.items():
    fishModes[$fm] = fm

  if not ctx.arguments.hasKey("mode") or not fishModes.hasKey(ctx.arguments["mode"]):
    await fs.echo(&"[[b;#ec3829;]Invalid mode, available: {$fishModes}]")
    return

  fs.fishState.mode = fishModes[ctx.arguments["mode"]]
  fs.gameState.config = none(Config)

  await fs.echo("Mode changed.")

proc commandsRegister(fs: FishServer) =
  let c = fs.commands

  c.onCommand("engine_reload", @[], "Reload engine"):
    discard fs.cmdEngineReload

  c.onCommand("config_reload", @[], "Reload all configs"):
    discard fs.cmdReload

  c.onCommand("help", @[], "Commands list"):
    discard fs.cmdHelp

  c.addCommand("set_mode", @[CommandParameter(variant: cmdArgument, name: "mode")], "") do(ctx: CommandContext):
    discard fs.cmdSetMode(ctx)
