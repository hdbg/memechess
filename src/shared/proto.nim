import std/options

type
  Move* = string

  ChessVariant* = enum
    cvStandard,
    cvAtomic,
    cvCrazyHouse,
    cvChess960,
    cvKingOfTheHill,
    cvThreeCheck,
    cvAntiChess,
    cvHorde,
    cvRacingKings

  ChessTime* = enum ctUltrabullet, ctBullet, ctBlitz, ctRapid, ctCorrespondence
  ChessSide* = enum csBlack, csWhite

  ChessClock* = object
    white*, black*: float
    inc*: Option[uint]

  ChessStep* = object
    fen*: string
    ply*: uint

    san*, uci*: Option[string]

    clock*: Option[ChessClock]

  ChessGameStart* = object
    id*: string

    steps*: seq[ChessStep]

    variant*: ChessVariant
    time*: ChessTime

    side*: ChessSide

    clock*: ChessClock

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
