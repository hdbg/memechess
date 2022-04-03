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

  ChessStep* = object
    fen*: string
    ply*: uint

    san*, uci*: Option[string]

  ChessGameStart* = object
    start*: seq[ChessStep]

    variant*: ChessVariant
    time*: ChessTime

    clock*: tuple[white, black, inc: float]

  TerminalInput* = object
    input*: string

  TerminalOutput* = object # TODO: Some echo options info
    output*: string
