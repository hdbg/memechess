import typing
from dataclasses import dataclass, field

from evilfish.core.types import Variant


@dataclass
class Move:
    san: typing.Optional[str] = None
    uci: typing.Optional[str] = None

    def verify(self):
        return self.san is not None or self.uci is not None


@dataclass
class NewGame:
    side: bool
    variant: Variant

    speed: str

    stack: typing.List[Move] = field(default_factory=[])

    fen: typing.Optional[str] = None
    ply: typing.Optional[int] = None


@dataclass
class UpdateRequest:
    ply: int
    fen: str

    black: float  # time in secs
    white: float

    move: Move


@dataclass
class EngineResponse:
    move: Move

    score: int = None
    win: float = None

    delay: float = 100.0
