import std/[asyncdispatch, os, distros, httpclient, distros, json]
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
    echo asset["name"].getStr()
    if asset["name"].getStr() == targetName:
      client.downloadFile(asset["browser_download_url"].getStr, "engine")
      return


when isMainModule:
  purple(logo)

  if not os.fileExists("engine"): downloadEngine()
  discard existsOrCreateDir("memechess")
  discard existsOrCreateDir("memechess" / "configs")

  waitFor http.main()
