import std/[asynchttpserver, asyncdispatch, asyncfutures, httpclient, strutils, options]
import chronicles
import std/[httpcore, uri]
import customsocket
import server/fish
import injector

const interceptPort = 8080

proc intercept(req: Request) {.async gcsafe.} =
  when defined trace: debug "intercept.received"

  const
    domain = "https://lichess.org"
    charSize = sizeof char

  let
    reqUrl = $req.url

  let http = newAsyncHttpClient()

  var headers = req.headers
  headers["host"] = "lichess.org"

  let resp = await http.request(domain & uri.`$`(req.url), httpMethod = req.reqMethod,
      headers = headers, body = req.body)

  when defined trace: debug "lichess.answer", status = resp.status, headers = resp.headers

  var
    body: string
    respHeaders = resp.headers

  if respHeaders.hasKey("content-type") and "html" in $respHeaders["content-type"]:
    body = await inject(resp)
  else:
    body = await resp.body()

  respHeaders["content-length"] = $(body.len * charSize)
  respHeaders.del "transfer-encoding"

  if respHeaders.hasKey "set-cookie":
    respHeaders["set-cookie"] = respHeaders["set-cookie"].replace(" Domain=lichess.org;", "")

  await req.respond(code = resp.code, content = $body,
      headers = resp.headers)


proc wsocket(req: Request) {.async gcsafe.} =
  debug "ws.connect"

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

        # when defined trace: debug "lisck.received", message=msg

        liMsg = liSck.receiveStrPacket()

      if sckMsg.finished:
        var msg  = sckMsg.read
        await liSck.send msg

        # when defined trace: debug "sck.received", message=msg

        sckMsg = sck.receiveStrPacket()

    except WebSocketError:
      break

  liSck.close()
  sck.close()

proc startChess(req: Request) {.async, gcsafe.} =
  var server {.global.}: Option[FishServer]

  if server.isNone:
    server = some(newFishServer())

  var chessSocket = await newWebsocket(req)

  get(server).conn = chessSocket

  while chessSocket.readyState == Open:
    try:
      let msg = await chessSocket.receiveStrPacket()
      get(server).handle(msg)
    except WebSocketError: return


proc dispatch(req: Request) {.async, gcsafe.} =
  let path = $req.url

  if "v5" in path or "v6" in path: await wsocket(req)
  elif "fish" in path: await startChess(req)
  else: await intercept(req)

proc main* {.async.} =
  var server = newAsyncHttpServer()

  server.listen(Port(interceptPort))
  let port = server.getPort

  info "evilfish.serve", port = port.int

  while true:
    await server.acceptRequest(dispatch)