import server/fish/interact/commands
import unittest2

suite "Test commands handler":
  var cd = newCommandDispatcher()

  when false:
    test "Short option parse":
      discard

    test "Argument parsing":
      discard

  test "Do notation":
    var called = false

    cd.addCommand("age", @[CommandParameter(name:"value", variant:cmdLongOption, kind:pkUInt)], "") do (ctx: CommandContext):
      if ctx.options["value"] == "44":
        called = true

    cd.dispatch("age --value=44")

    check: called
