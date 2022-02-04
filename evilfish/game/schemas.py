from pydantic import BaseModel, Field
from .types import Variant
import typing
import chess


class GameCrazyHousePocketSchema(BaseModel):
    pawn: int = Field(int, default=16)
    horse: int = Field(int, default=0, le=4)
    bishop: int = Field(int, default=0, le=4)
    rook: int = Field(int, default=0, le=4)
    queen: int = Field(int, default=0, le=2)


class GameStartSchema(BaseModel):
    id: str
    variant: Variant

    player_side: chess.Color

    white_pocket: typing.Optional[GameCrazyHousePocketSchema]
    black_pocket: typing.Optional[GameCrazyHousePocketSchema]

    inc: typing.Optional[float] = 0.0

    white_clock: typing.Optional[float] = 0.0
    black_clock: typing.Optional[float] = 0.0

    history: typing.List[str]


class GameMoveSchema(BaseModel):
    fen: str
    color: chess.Color

    move: typing.Optional[str]
    drop: typing.Optional[str]

    ply: int

#
# class GameEngineResponseSchema(BaseModel):
