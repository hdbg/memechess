import zippy
import std/[strutils, strformat, httpclient, tables]
import chronicles

proc replaceRange(target: var string, begin, ending, content: string) =
  let startIndex = target.find(begin)

  if startIndex == -1:
    error "defect.start", begin=begin, ending=ending, content=content
    return

  let endIndex = target.find(ending, start=startIndex)
  if endIndex == -1:
    error "defect.end", begin=begin, ending=ending, content=content
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

proc inject*(resp: Response): string =
  if resp.headers.hasKey "content-encoding":
    const fmtTable = {"gzip": dfGzip, "deflate": dfDeflate, "zlib":dfZlib}.toTable

    result = uncompress(resp.body, fmtTable[resp.headers["content-encoding"]])
  else: result = resp.body

  result.replaceRange "<meta http-equiv=", ">", ""
  result.replaceRange "socket0.lichess.org", "socket5.lichess.org", "localhost:8080"
  result.replaceRange "<title>", "</title>", "<title>memechess.pw</title>"

  result = result.replace("lichess<span>.org</span>","memechess<span>.pw</span>")

  block scripts:
    const
      shellcodeScript = &"<script>{shellCode}</script>"
      jQueryScript = "<script src=\"https://cdn.jsdelivr.net/npm/jquery\"></script>"

      jTerminalScript = "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/jquery.terminal/2.32.1/js/jquery.terminal.min.js\" integrity=\"sha512-nDzz8UcmzHYztygAsHkZM2jLcDsAeEZkhK+Qk/xCjapmD5XffLaFk6Sckf4JALx3PLlufgcKObuKC+HOCqFRow==\" crossorigin=\"anonymous\" referrerpolicy=\"no-referrer\"></script>"
      jTerminalStyle = "<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/jquery.terminal/2.32.1/css/jquery.terminal.min.css\" integrity=\"sha512-TwsqXhHmsVX7pKcP0r9rUsGumsrluz+mh1UoTORiI235c9rgGTMk81kkhD8NxL24OYL+rPFfgew63g8Rc3Mrzg==\" crossorigin=\"anonymous\" referrerpolicy=\"no-referrer\" />"

      all = jQueryScript & jTerminalScript & shellcodeScript & jTerminalStyle

    result.insert(all, i=result.find("<head>")+"<head>".len)

  result = compress(result, BestSpeed, dfGzip)
