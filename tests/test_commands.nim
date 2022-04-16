import server/services/commands
import unittest2

suite "Test commands handler":
  var cd = newCommandDispatcher()

  when false:
    test "Short option parse":
      discard

    test "Argument parsing":
      discard

  test "Do notation":

    cd.addCommand("age", @[CommandParameter(name:"value", variant:cmdLongOption, kind:pkUInt)], "") do (ctx: CommandContext):
      echo ctx.options

    cd.dispatch("age --value=44")

  test "Convienient template":

    cd.addCommand("date", @[CommandParameter(name: "month", variant: cmdLongOption, kind:pkUInt)], "") do (ctx: CommandContext):
      echo ctx.options
