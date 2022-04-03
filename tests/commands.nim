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
