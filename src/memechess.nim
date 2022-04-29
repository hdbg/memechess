import std/[asyncdispatch, strutils, strformat, times]
import termstyle
import chronicles

const
  logo = """                                            __
                                           /\ \
  ___ ___      __    ___ ___      __    ___\ \ \___      __    ____    ____
/' __` __`\  /'__`\/' __` __`\  /'__`\ /'___\ \  _ `\  /'__`\ /',__\  /',__\
/\ \/\ \/\ \/\  __//\ \/\ \/\ \/\  __//\ \__/\ \ \ \ \/\  __//\__, `\/\__, `\
\ \_\ \_\ \_\ \____\ \_\ \_\ \_\ \____\ \____\\ \_\ \_\ \____\/\____/\/\____/
 \/_/\/_/\/_/\/____/\/_/\/_/\/_/\/____/\/____/ \/_/\/_/\/____/\/___/  \/___/ """
  footer = block:
    let
     realFooter = "Gigachad Software 2022 (c)"

     logoLines = logo.splitLines
     logoLineLength = len(logoLines[len(logoLines) div 2])

    repeat(' ', logoLineLength - realFooter.len) & realFooter



# MEME LICENSE CHECK

let f = initTimeFormat("yyyy-MM-dd")

when defined release:
  if (CompileDate.parse(f, utc()) + initDuration(days=1)) < utc(now()):
    quit()

echo green logo
echo blue blink(footer)

const prefix =
  when not defined release:
    "Dev Build"
  else:
    "Build"

echo magenta &"{prefix} [{CompileDate} {CompileTime}]"

import http
waitFor http.main()
