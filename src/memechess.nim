import std/[asyncdispatch, os, distros, httpclient, json, times]
import std/[strutils, strformat, times]
import fab
import http
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

proc downloadEngine() =
  info "engine.downloading"

  let client = newHttpClient()

  let
    releasesData = client.getContent("https://api.github.com/repos/ianfab/Fairy-Stockfish/releases/latest")
    releases = parseJson(releasesData)

  let targetName = block:
    var result = "fairy-stockfish-largeboard_x86-64"

    if detectOs(Windows):
      result.add ".exe"

    result

  for asset in releases["assets"].items():
    if asset["name"].getStr() == targetName:
      client.downloadFile(asset["browser_download_url"].getStr, "mchess" / "engine.exe")
      return

  info "engine.ok"

# MEME LICENSE CHECK

when isMainModule:
  let f = initTimeFormat("yyyy-MM-dd")

  when defined release:
    if (CompileDate.parse(f, utc()) + initDuration(days=1)) < utc(now()):
      quit()

  purple(logo)
  blue(footer)

  let prefix =
    when not defined release:
      "Dev Build: "
    else:
      "Build: "

  echo &"{prefix} {CompileDate} {CompileTime}"

  discard existsOrCreateDir("mchess")
  discard existsOrCreateDir("mchess" / "configs")
  discard existsOrCreateDir("mchess" / "scripts")

  if not os.fileExists("mchess" / "engine.exe"): downloadEngine()

  waitFor http.main()
