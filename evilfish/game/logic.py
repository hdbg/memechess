import typing

import chess
import chess.variant
from evilfish.log import logger
from . import types, schemas


class GameLogic:
    game: typing.Type[chess.Board]

    side: chess.Color
    inc: float

    async def new_game(self, data: schemas.GameStartSchema) -> bool:
        self.game = chess.variant.find_variant(data.variant.value)()
        self.side = data.player_side

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

    async def _query_engine(self):
        pass


game_logic = GameLogic()
