import typing

import chess
import chess.engine
import chess.variant
from evilfish.core.engine import engine
from evilfish.log import logger, console
from evilfish.strategies import schemas as strategy_schemas
from evilfish.strategies.strategy import Strategy, strategy_manager
from . import types, schemas


class GameLogic:
    game: chess.Board
    strategy: Strategy

    side: chess.Color
    inc: float = 0.0

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

    async def push_move(self, data: schemas.GameMoveSchema) -> typing.Optional[schemas.GameEngineResponseSchema]:
        if data.move:
            self.game.push_uci(data.move)
        elif data.drop:
            pass

        if self.game.turn == self.side:
            return await self._query_engine(data)

    def _get_strategy_and_eval(self, var: strategy_schemas.TriggerVars) -> strategy_schemas.TriggerResult:
        logger.debug("game.strategy_search.vars", var=var)

        self.strategy = strategy_manager.find(self.variant, var)
        if self.strategy is None:
            logger.fatal("game.strategy_not_found")
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

    def _fix_limit(self, query: schemas.GameMoveSchema):
        limit = chess.engine.Limit(white_inc=self.inc,
                                   black_inc=self.inc)

        if query.black_clock is not None and query.white_clock is not None:
            limit.white_clock = query.white_clock
            limit.black_clock = query.black_clock

        if limit.white_clock is None and limit.black_clock is None:
            limit.time = 60.0  # Fix infinite analyse

        return limit

    async def _query_engine(self, query: schemas.GameMoveSchema) -> schemas.GameEngineResponseSchema:
        my_time = (query.white_clock if self.side == chess.WHITE else query.black_clock) or 0
        enemy_time = ((query.white_clock or 0) + (query.black_clock or 0)) - my_time

        score = await self._get_score()

        trigger_result = self._get_strategy_and_eval(
            strategy_schemas.TriggerVars(my_score=score, my_time=my_time, enemy_time=enemy_time))
        logger.debug("strategy.result", data=trigger_result)

        # Actual engine query
        limit = self._fix_limit(query)
        limit.depth = trigger_result.delay

        engine_opts = {}
        if trigger_result.elo is not None:
            engine_opts["UCI_LimitStrength"] = True
            engine_opts["UCI_ELo"] = trigger_result.elo

        logger.debug("game.engine.sent", board=self.game, limit=limit, opts=engine_opts)

        with console.status("Engine thinking"):
            p_result: chess.engine.PlayResult = await engine.play(self.game, limit, opts=engine_opts)
            self.last_score = p_result.info.get("score").relative.score()

        logger.debug("game.engine.result", result=p_result)

        return schemas.GameEngineResponseSchema(move=p_result.move.uci(), score=self.last_score,
                                                delay=trigger_result.delay)


game_logic = GameLogic()
