import std/[asyncdispatch, strutils, strformat]
import termstyle

const
  logo = """                                            __
                                           /\ \
  ___ ___      __    ___ ___      __    ___\ \ \___      __    ____    ____
/' __` __`\  /'__`\/' __` __`\  /'__`\ /'___\ \  _ `\  /'__`\ /',__\  /',__\
/\ \/\ \/\ \/\  __//\ \/\ \/\ \/\  __//\ \__/\ \ \ \ \/\  __//\__, `\/\__, `\
\ \_\ \_\ \_\ \____\ \_\ \_\ \_\ \____\ \____\\ \_\ \_\ \____\/\____/\/\____/
 \/_/\/_/\/_/\/____/\/_/\/_/\/_/\/____/\/____/ \/_/\/_/\/____/\/___/  \/___/ """

  version = block:
    proc iFind(str, sub: string, start=0): int =
      result = str.find(sub, start=start)
      if result != -1:
        result.inc sub.len

    let nContent = staticRead"memechess.nimble"

    let
      left = nContent.iFind("\"", nContent.iFind("version"))
      right = nContent.iFind("\"", left) - 2 # weird index shit

    nContent[left..right]

  footer = block:
    let
     realFooter = &"Gigachad Software 2022 (c) v.{version}"

     logoLines = logo.splitLines
     logoLineLength = len(logoLines[len(logoLines) div 2])

    repeat(' ', logoLineLength - realFooter.len) & realFooter


# Setup error hook
unhandledExceptionHook = proc(e: ref Exception) =
  when defined release:
    echo red e.name
  else:
    echo red e.msg

  quit(QuitFailure)

# MEME LICENSE CHECK
when false:
  let f = initTimeFormat("yyyy-MM-dd")

  when defined release:
    if (CompileDate.parse(f, utc()) + initDuration(days=1)) < utc(now()):
      quit()

echo green logo
echo blue footer

const prefix =
  when not defined release:
    "Dev Build"
  else:
    "Build"

echo magenta &"{prefix} [{CompileDate} {CompileTime}]"

import http
waitFor http.main()
