import typing
from enum import Enum

from evilfish.game import types
from pydantic import BaseModel, Field


class StrategyType(Enum):
    legit = "legit"
    rage = "rage"


class TriggerType(Enum):
    by_my_score = "score"
    # by_enemy_score = "enemy_score"
    by_time_left = "time"


class LogicOperatorType(Enum):
    less_then = "lt"
    less_equals = "le"
    equals = "eq"
    not_equals = "ne"
    greater_equals = "ge"
    greater_then = "gt"


class ActionScheme(BaseModel):
    delay: str = Field(...)
    depth: str = Field(...)
    elo: str = Field(...)


class TriggerScheme(BaseModel):
    type: TriggerType = Field(...)
    op: LogicOperatorType = Field(...)
    rhs: typing.Union[int, float] = Field(...)

    on_active: ActionScheme = Field(...)


class StrategyScheme(BaseModel):
    type: StrategyType = Field(StrategyType.rage)
    variants: typing.List[types.Variant] = Field(...)
    priority: int = Field(1, ge=1)

    auto_next: bool = Field(False)
    auto_first_move: bool = Field(False)

    triggers: typing.List[TriggerScheme] = Field([])


class TriggerResult(BaseModel):
    delay: float = 0.0
    depth: typing.Optional[int] = Field(None, ge=0)
    elo: typing.Optional[int] = Field(None, ge=500, le=2850)


class TriggerVars(BaseModel):
    my_time: float
    enemy_time: float
    my_score: int
