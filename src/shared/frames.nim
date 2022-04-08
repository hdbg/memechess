import std/[json, tables, asyncfutures, jsonutils]

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
      decoded = jsonTo(raw, T)

    cb(decoded)

  fh.handlers[kind] = decode

template handle*(fh: FramesHandler, t: typedesc, body: untyped) =
  proc newCallback(d: t) =
    var data {.inject.}: t = d
    body

  addHandler[t](fh, newCallback)

proc framify*[T](data: T): string =
  var kind = $(T)
  var encoded = $(toJson(data))

  $(%DataFrame(kind: kind, data: encoded))

proc dispatch*(fh: FramesHandler, data: string) =
  let raw = parseJson(data)
  let frame = json.to(raw, DataFrame)

  for (kind, handler) in fh.handlers.pairs():
    if frame.kind == kind: handler(frame.data)
