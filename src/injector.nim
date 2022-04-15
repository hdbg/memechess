import zippy
import std/[strutils, strformat, httpclient, tables, asyncdispatch]
import chronicles

proc replaceRange(target: var string, begin, ending, content: string) =
  let startIndex = target.find(begin)

  if startIndex == -1:
    return

  let endIndex = target.find(ending, start=startIndex)
  if endIndex == -1:
    return

  target[startIndex..(endIndex - 1 + ending.len)] = content

static:
  var
    output {.compileTime.}: string
    eCode {.compileTime.}: int

  when defined release:
    (output, eCode) = gorgeEx "nim js -d:release client/loader.nim"
  else:
    (output, eCode) = gorgeEx "nim js client/loader.nim"

  if eCode == 1:
    echo output
    raise ValueError.newException("Client compilation error")

const shellCode = staticRead"shellcode.js"

proc inject*(resp: AsyncResponse): Future[string] {.async.} =
  let body = await resp.body()

  if resp.headers.hasKey "content-encoding":
    const fmtTable = {"gzip": dfGzip, "deflate": dfDeflate, "zlib":dfZlib}.toTable

    result = uncompress(body, fmtTable[resp.headers["content-encoding"]])
  else: result = body

  result.replaceRange "<meta http-equiv=", ">", ""
  result.replaceRange "socket0.lichess.org", "socket5.lichess.org", "localhost:8080"
  result.replaceRange "<title>", "</title>", "<title>memechess.pw</title>"

  result = result.replace("lichess<span>.org</span>","memechess<span>.pw</span>")

  block scripts:
    const
      shellcodeScript = &"<script>{shellCode}</script>"
      jQueryScript = "<script src=\"https://code.jquery.com/jquery-3.2.1.min.js\"></script>"

      jTerminalScript = "<script src=\"https://unpkg.com/jquery.terminal/js/jquery.terminal.min.js\"></script>"
      jTerminalStyle = "<link href=\"https://unpkg.com/jquery.terminal/css/jquery.terminal.min.css\" rel=\"stylesheet\"/>"

      all = jQueryScript & jTerminalScript & shellcodeScript & jTerminalStyle

    result.insert(all, i=result.find("<head>")+"<head>".len)

  result = compress(result, BestSpeed, dfGzip)
