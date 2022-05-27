import std/options

type
  Move* = string

  Variant* = enum
    cvStandard,
    cvAtomic,
    cvCrazyHouse,
    cvChess960,
    cvKingOfTheHill,
    cvThreeCheck,
    cvAntiChess,
    cvHorde,
    cvRacingKings

  Time* = enum ctUltrabullet, ctBullet, ctBlitz, ctRapid, ctCorrespondence
  Side* {.pure.} = enum
    csBlack
    csWhite

  Clock* = object
    white*, black*: float
    inc*: Option[uint]

  Step* = object
    fen*: string
    ply*: uint

    san*, uci*: Option[string]

    clock*: Option[Clock]

  GameStart* = object
    id*: string

    steps*: seq[Step]

    variant*: Variant
    time*: Time

    side*: Side

    clock*: Option[Clock]

  TerminalInput* = object
    text*: string

  TerminalOutput* = object # TODO: Some echo options info
    text*: string

  Ping* = object
    time*: uint

  PingResponse* = object
    time*: uint

  ShortEngineInfo* = object
    nodes*, depth*, nps*: Option[uint]
    score*: Option[int]

  EngineStep* = object
    move*: string
    delay*: uint
    premove*: bool
