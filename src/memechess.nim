import std/[asyncdispatch, os, distros, httpclient, distros, json]
import std/[times]
import fab
import http

const logo = """                                            __
                                           /\ \
  ___ ___      __    ___ ___      __    ___\ \ \___      __    ____    ____
/' __` __`\  /'__`\/' __` __`\  /'__`\ /'___\ \  _ `\  /'__`\ /',__\  /',__\
/\ \/\ \/\ \/\  __//\ \/\ \/\ \/\  __//\ \__/\ \ \ \ \/\  __//\__, `\/\__, `\
\ \_\ \_\ \_\ \____\ \_\ \_\ \_\ \____\ \____\\ \_\ \_\ \____\/\____/\/\____/
 \/_/\/_/\/_/\/____/\/_/\/_/\/_/\/____/\/____/ \/_/\/_/\/____/\/___/  \/___/ """

proc downloadEngine() =
  let client = newHttpClient()

  let
    releasesData = client.getContent("https://api.github.com/repos/ianfab/Fairy-Stockfish/releases/latest")
    releases = parseJson(releasesData)

  var targetName: string

  if detectOs(Linux):
    targetName = "fairy-stockfish-largeboard_x86-64"
  elif detectOs(Windows):
    targetName = "fairy-stockfish-largeboard_x86-64.exe"

  for asset in releases["assets"].items():
    if asset["name"].getStr() == targetName:
      client.downloadFile(asset["browser_download_url"].getStr, "engine.exe")
      return


# MEME LICENSE CHECK

when isMainModule:
  let f = initTimeFormat("yyyy-MM-dd")

  if (CompileDate.parse(f, utc()) + initDuration(days=1)) < utc(now()):
    quit()

  purple(logo)

  if not os.fileExists("engine.exe"): downloadEngine()
  discard existsOrCreateDir("mchess")
  discard existsOrCreateDir("mchess" / "configs")

  waitFor http.main()
