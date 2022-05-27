import std/[dom, jsffi, options, tables]
import shared/proto

proc createAnchor*(parent: string, child_id: string) =
  var ancestorRaw = document.getElementsByClassName(parent)

  if ancestorRaw.len != 1:
    raise ValueError.newException("Can't find ui root")
  var ancestor = ancestorRaw[0]

  var anchor = document.createElement("div")
  anchor.setAttribute("id", child_id)

  ancestor.appendChild(anchor)

proc toSome*[T](data: JsObject): Option[T] = some(data.to(T))
proc `$`*(data: JsObject): string = $(data.to(cstring))

proc createStart*(opts: JsObject): GameStart =
  const
      varTable = {
        "Standard": cvStandard,
        "Atomic": cvAtomic,
        "Crazyhouse": cvCrazyHouse
      }.toTable # TODO MORe

      timeTable = {
        "blitz": ctBlitz,
        "bullet": ctBullet,
        "rapid": ctRapid,
        "ultraBullet": ctUltrabullet,
        "correspondence": ctCorrespondence
      }.toTable

  let
    data = opts.data
    game = data.game

  result.id = $game.id

  result.time = timeTable[$game.speed]
  result.variant = varTable[$game.variant.name]

  result.side = if $data.player.color == "white": csWhite else: csBlack

  if data.clock != jsUndefined:
    let clock = data.clock

    var newClock = Clock(
      white: clock.white.to(float),
      black: clock.black.to(float)
    )

    if clock.inc != jsUndefined:
      newClock.inc = toSome[uint](clock.inc)

    result.clock = some newClock

  for step in (data.steps.to(seq[JsObject])):
    if step.uci != jsNull and step.san != jsNull:
      result.steps.add Step(
        fen: $step.fen,
        uci: some($step.uci),
        san: some($step.san),
        ply: step.ply.to(uint)
      )
