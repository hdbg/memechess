import std/[asynchttpserver, asyncdispatch, asyncfutures, httpclient, strutils]
import chronicles
import std/[httpcore, uri]
import customsocket
import chess/server
import injector

const interceptPort = 8080

proc intercept(req: Request) {.async gcsafe.} =
  debug "intercept.received", req = req

  const
    domain = "https://lichess.org"
    charSize = sizeof char

  let http = newHttpClient()

  var headers = req.headers
  headers["host"] = "lichess.org"

  let resp = http.request(domain & uri.`$`(req.url), httpMethod = req.reqMethod,
      headers = headers, body = req.body)

  debug "lichess.answer", status = resp.status, headers = resp.headers

  var
    body = inject resp
    respHeaders = resp.headers

  respHeaders["content-length"] = $(body.len * charSize)
  respHeaders.del "transfer-encoding"

  if respHeaders.hasKey "set-cookie":
    respHeaders["set-cookie"] = respHeaders["set-cookie"].replace(" Domain=lichess.org;")

  await req.respond(code = resp.code, content = $body,
      headers = resp.headers)


proc wsocket(req: Request) {.async gcsafe.} =
  debug "ws.connect", req=req

  var sck = await newWebsocket(req)

  var liSck = await customsocket.newWebsocket("wss://socket0.lichess.org" & $(req.url), req.headers)

  var liMsg = liSck.receiveStrPacket()
  var sckMsg = sck.receiveStrPacket()

  while liSck.readyState == Open and sck.readyState == Open:
    try:
      await (liMsg or sckMsg)

      if liMsg.finished:
        var msg = liMsg.read
        await sck.send msg

        when defined trace: debug "lisck.received", message=msg

        liMsg = liSck.receiveStrPacket()

      if sckMsg.finished:
        var msg  = sckMsg.read
        await liSck.send msg

        when defined trace: debug "sck.received", message=msg

        sckMsg = sck.receiveStrPacket()

    except WebSocketError:
      break

  liSck.close()
  sck.close()

proc startChess(req: Request) {.async.} =
  var fs = await newFishServer(req)
  asyncCheck fs.listen()

proc dispatch(req: Request) {.async, gcsafe.} =
  let path = $req.url

  if "v5" in path or "v6" in path: await wsocket(req)
  elif "fish" in path: await startChess(req)
  else: await intercept(req)

proc main {.async.} =
  var server = newAsyncHttpServer()

  server.listen(Port(interceptPort))
  let port = server.getPort

  info "evilfish.serve", port = port.int

  while true:
    await server.acceptRequest(dispatch)


waitFor main()
