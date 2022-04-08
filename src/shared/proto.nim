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

  ChessTime* = enum ctUltrabullet, ctBullet, ctBlitz, ctRapid
  ChessSide* = enum csBlack, csWhite

  ChessStep* = object
    fen*: string
    ply*: uint

    san*, uci*: Option[string]

  ChessClock* = object
    white*, black*, inc*: Option[uint]

  ChessGameStart* = object
    id*: string

    steps*: seq[ChessStep]

    variant*: ChessVariant
    time*: ChessTime

    side*: ChessSide

    clock*: ChessClock

  TerminalInput* = object
    input*: string

  TerminalOutput* = object # TODO: Some echo options info
    output*: string

  Ping* = object
    time: uint
  PingResponse* = object
    time: uint
