from enum import Enum

import chess


class Variant(Enum):
    standard = "Standard"
    crazyhouse = "Crazyhouse"
    chess960 = "Chess960"
    koth = "King of The Hill"
    three = "Three-check"
    antichess = "Antichess"
    atomic = "Atomic"
    horde = "Horde"
    racing = "Racing Kings"


class Mode(Enum):
    legit = "legit"
    rage = "rage"


class Game:
    board: chess.Board
    player_side: chess.Color
    variant: Variant

    mode: Mode
    speed: str
