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
    fen*: cstring
    ply*: cuint

    san*, uci*: Option[cstring]

  ChessGameStart* = object
    start*: seq[ChessStep]

    variant*: ChessVariant
    time*: ChessTime

    clock*: tuple[white, black, inc: float]
