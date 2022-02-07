import typing

import chess
import chess.engine
import chess.variant
from evilfish.core.engine import engine
from evilfish.log import logger
from evilfish.strategies import schemas as strategy_schemas
from evilfish.strategies.strategy import Strategy, strategy_manager
from . import types, schemas


class GameLogic:
    game: chess.Board
    strategy: Strategy

    side: chess.Color
    inc: float

    variant: types.Variant

    last_score: int = None

    async def new_game(self, data: schemas.GameStartSchema) -> bool:
        self.game = chess.variant.find_variant(data.variant.value)()
        self.side = data.player_side
        self.variant = data.variant.value

        self.last_score = None

        if data.variant == types.Variant.crazyhouse:
            # TODO: Crazyhouse prep
            pass

        self.inc = data.inc

        for move in data.history:
            self.game.push(move=chess.Move.from_uci(move))

        logger.info("playing", id=data.id, variant=data.variant.value)

        return True

    async def push_move(self, data: schemas.GameMoveSchema) -> typing.Optional:
        if data.move:
            self.game.push_uci(data.move)
        elif data.drop:
            pass

        if self.game.turn == self.side:
            # TODO: Launch engined
            pass

    def _get_strategy_and_eval(self, var: strategy_schemas.TriggerVars) -> strategy_schemas.TriggerResult:
        logger.debug("game.strategy_search.vars", var=var)

        self.strategy = strategy_manager.find(self.variant, var)
        if self.strategy is None:
            logger.error("game.strategy_not_found")
            return

        return self.strategy.eval(var)

    async def _get_score(self) -> int:
        if self.last_score is not None:
            return self.last_score
        else:
            analyse_result = await engine.analyse(self.game, chess.engine.Limit(time=0.01))
            score_obj = analyse_result.get("score").relative

            logger.debug("engine.score.first", data=score_obj.score())
            return score_obj.score()

    async def _query_engine(self, query: schemas.GameMoveSchema) -> schemas.GameEngineResponseSchema:
        limit = chess.engine.Limit(white_clock=query.white_clock, black_clock=query.black_clock, white_inc=self.inc,
                                   black_inc=self.inc)

        my_time = (query.white_clock if self.side == chess.WHITE else query.black_clock) or 0
        enemy_time = ((query.white_clock or 0) + (query.black_clock or 0)) - my_time

        score = await self._get_score()

        trigger_result = self._get_strategy_and_eval(
            strategy_schemas.TriggerVars(my_score=score, my_time=my_time, enemy_time=enemy_time))

        logger.debug("strategy.result", data=trigger_result)


game_logic = GameLogic()
