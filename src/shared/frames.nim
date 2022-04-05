import std/[json, tables, asyncfutures]

type
  HandlerCallback = proc(data: string)

  DataFrame = object
    kind: string
    data: string

  FramesHandler* = ref object
    handlers: Table[string, HandlerCallback]

proc addHandler*[T](fh: FramesHandler, cb: proc(data: T)) =
  var kind = $(T)

  proc decode(data: string) =
    var
      raw = parseJson(data)
      decoded = json.to(raw, T)

    cb(decoded)

  fh.handlers[kind] = decode

proc addHandler*[T](fh: FramesHandler, cb: proc(data: T): Future[void]) =
  var kind = $(T)

  proc decode(data: string) =
    var
      raw = parseJson(data)
      decoded = json.to(raw, T)

    asyncCheck cb(decoded)

  fh.handlers[kind] = decode

proc framify*[T](data: T): string =
  var kind = $(T)
  var encoded = $(%data)

  $(%DataFrame(kind: kind, data: encoded))

proc handle*(fh: FramesHandler, data: string) =
  let raw = parseJson(data)
  let frame = json.to(raw, DataFrame)

  for (kind, handler) in fh.handlers.pairs():
    if frame.kind == kind: handler(frame.data)
