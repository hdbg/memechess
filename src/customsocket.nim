import ws
import std/[httpclient, httpcore, asyncdispatch, base64, asyncnet, uri, strformat]
import std/[strutils, random, tables]

export ws

proc newWebSocket*(
  url: string,
  headers: HttpHeaders,
  protocols: seq[string] = @[]
): Future[WebSocket] {.async.} =
  ## Creates a new WebSocket connection,
  ## protocol is optional, "" means no protocol.
  var ws = WebSocket()
  ws.masked = true
  ws.tcpSocket = newAsyncSocket()

  var uri = parseUri(url)
  var port = Port(9001)
  case uri.scheme
    of "wss":
      uri.scheme = "https"
      port = Port(443)
    of "ws":
      uri.scheme = "http"
      port = Port(80)
    else:
      raise newException(
        WebSocketError,
        &"Scheme {uri.scheme} not supported yet"
      )
  if uri.port.len > 0:
    port = Port(parseInt(uri.port))

  var client = newAsyncHttpClient()

  # Generate secure key.
  var secStr = newString(16)
  for i in 0 ..< secStr.len:
    secStr[i] = char rand(255)
  let secKey = base64.encode(secStr)

  let sckHeaders = {
      "Connection": "Upgrade",
      "Upgrade": "websocket",
      "Sec-WebSocket-Version": "13",
      "Sec-WebSocket-Key": secKey,
      # "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits"
    }.toTable

  for k, v in sckHeaders:
    headers[k] = v

  client.headers = headers

  when false:
    client.headers = newHttpHeaders()

  if protocols.len > 0:
    client.headers["Sec-WebSocket-Protocol"] = protocols.join(", ")
  var res = await client.get($uri)
  let hasUpgrade = res.headers.getOrDefault("Upgrade")
  if hasUpgrade.toLowerAscii() != "websocket":
    raise newException(
      WebSocketFailedUpgradeError,
      &"Failed to Upgrade (Possibly Connected to non-WebSocket url)"
    )
  if protocols.len > 0:
    var resProtocol = res.headers.getOrDefault("Sec-WebSocket-Protocol")
    if resProtocol in protocols:
      ws.protocol = resProtocol
    else:
      raise newException(
        WebSocketProtocolMismatchError,
        &"Protocol mismatch (expected: {protocols}, got: {resProtocol})"
      )
  ws.tcpSocket = client.getSocket()

  ws.readyState = Open
  return ws
