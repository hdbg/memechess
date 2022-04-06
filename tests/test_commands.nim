import chess/commands
import unittest2

suite "Test commands handler":
  var cd = newCommandDispatcher()


  test "Long option parse":
    var isOk = false

    let line = "hello --name=John"
    cd.onCommand("hello", @[CommandParameter(name:"name", variant: cmdLongOption, kind:pkString)]):
      isOk = true
      echo ctx.options["name"]

    cd.dispatch(line)


  when false:
    test "Short option parse":
      discard

    test "Argument parsing":
      discard

  test "Do notation":

    cd.addCommand("age", @[CommandParameter(name:"value", variant:cmdLongOption, kind:pkUInt)]) do (ctx: CommandContext):
      echo ctx.options

    cd.dispatch("age --value=44")

  test "Convienient template":

    cd.onCommand("date", @[CommandParameter(name: "month", variant: cmdLongOption, kind:pkUInt)]):
      echo ctx.options
