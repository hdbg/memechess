import math
import operator
import os
import random
import typing

import expression
import orjson
from evilfish.core import consts
from evilfish.game import types
from evilfish.log import logger
from . import schemas


class Strategy:
    raw: schemas.StrategyScheme
    variants: typing.List[types.Variant]

    triggers: typing.List[schemas.TriggerScheme]
    priority: int

    def __init__(self, strategy: schemas.StrategyScheme):
        self.raw = strategy
        self.priority = strategy.priority
        self.triggers = strategy.triggers

        self.variants = strategy.variants

    def would_fire(self, var: schemas.TriggerVars):
        lhs_map = {
            "score": var.my_score,
            "time": var.my_time
        }

        for trigger in self.triggers:
            op = getattr(operator, trigger.op.value)
            lhs = lhs_map[trigger.type.value]

            if op(lhs, trigger.rhs):
                return True
            else:
                logger.debug("strategy.trigger.not_fired", trigger=trigger)

        return False

    def eval(self, var: schemas.TriggerVars) -> schemas.TriggerResult:
        lhs_map = {
            "score": var.my_score,
            "time": var.my_time
        }

        parser = expression.Expression_Parser(variables=var.dict(),
                                              functions=
                                              dict(randint=random.randint, pow=math.pow, sqrt=math.sqrt)).parse

        for trigger in self.triggers:
            op = getattr(operator, trigger.op.value)
            lhs = lhs_map[trigger.type.value]

            if not op(lhs, trigger.rhs):
                continue

            result = schemas.TriggerResult()

            result.delay = parser(trigger.on_active.delay)
            result.depth = parser(trigger.on_active.depth)
            result.elo = parser(trigger.on_active.elo)

            self._verify_types(result)

            return result

    def _verify_types(self, result: schemas.TriggerResult):
        for name, type_hint in typing.get_type_hints(schemas.TriggerResult).items():
            if not isinstance(getattr(result, name), type_hint):
                logger.error("strategy.type_mismatch", name=name, type=type_hint)
                raise TypeError(
                    f"Field {name} mismatched type: supposed - {str(type_hint)}, real - {str(type(getattr(result, name)))}")


class StrategyManager:
    _strategies: typing.List[Strategy] = []

    def load(self):
        for entry in os.scandir(consts.APP_STRATEGIES_FOLDER):
            entry: os.DirEntry = entry  # because of stupid IDE types
            logger.debug("strategy.file_found", name=entry.name)

            if not entry.is_file() or not entry.name.endswith(".json"):
                logger.debug("strategy.file_incorrect", name=entry.name)
                continue

            # TODO Make error checks
            with open(consts.APP_STRATEGIES_FOLDER + entry.name, "rb") as f:
                raw_content = orjson.loads(f.read())

            model = schemas.StrategyScheme.parse_obj(raw_content)
            model.triggers = sorted(model.triggers, key=lambda x: x.rhs)

            logger.debug("strategy.imported", data=model)

            self._strategies.append(Strategy(model))

        self._strategies = sorted(self._strategies, key=lambda x: x.priority)

    def find(self, variant: types.Variant, var: typing.Optional[schemas.TriggerVars] = None):
        for strategy in filter(lambda s: variant not in s.variants, self._strategies):
            if var is not None and strategy.would_fire(var):
                return strategy


strategy_manager = StrategyManager()
