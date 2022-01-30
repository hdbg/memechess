from dataclasses import asdict
from datetime import datetime

import chess.engine
import chess.variant
from fastapi import Response, FastAPI

from evilfish.core.controller import BaseController
from evilfish.core.engine import engine
from evilfish.core.log import logger
from evilfish.core.types import *
from .models import *


class GameController(BaseController):
    board: chess.BoardT
    side: chess.Color

    variant: Variant
    mode: Mode

    speed: str

    def __init__(self):
        self.router.add_api_route("/game/new", self.new, methods=["POST"])
        self.router.add_api_route("/game/push", self.push, methods=["POST"])

    def _move_deserialize(self, m: Move):
        if m.uci is not None:
            return chess.Move.from_uci(m.uci)
        elif m.san is not None:
            return self.board.parse_san(m.san)

    async def new(self, r: NewGame) -> dict:
        self.speed = r.speed

        self.side = chess.Color(r.side)
        self.variant = Variant(r.variant)

        self.board = chess.variant.find_variant(self.variant.value)()

        for m in r.stack:
            m = self._move_deserialize(m)
            self.board.push(m)

        logger.info("game.new", variant=self.variant.value, speed=self.speed, side=self.side, fen=self.board.fen())

        return self.json("game.new", {})

    async def push(self, r: UpdateRequest, response: Response) -> dict:
        m = self._move_deserialize(r.move)

        if not self.board.is_legal(m):
            logger.error("game.illegal", move=m.uci())
            return self.error("game.illegal")

        self.board.push(m)

        if (bfen := self.board.board_fen()) != r.fen:
            logger.error("game.desync", client=r.fen, server=bfen)
            return self.error("game.desync", "Board got desynced!")

        logger.info("game.moved", move=m.uci(), turn=self.board.turn)

        if self.board.is_game_over():
            logger.info("game.end")
            return

        if self.board.turn == self.side:
            return self.json("game.engine", asdict(await self.think(r)))

        return self.json("game.moved")

    async def take_back(self, response: Response) -> dict:
        pass

    async def think(self, r: UpdateRequest) -> EngineResponse:
        before = datetime.now()

        pr = await engine.play(self.board, limit=chess.engine.Limit(black_clock=r.black, white_clock=r.white))
        delta = (datetime.now() - before).microseconds

        _score = pr.info["score"].relative

        score = int(_score.score() or 0)
        win_rate = _score.wdl(ply=self.board.ply()).winning_chance() or 0.0

        logger.info("game.engine", move=pr.move.uci(), time=delta, score=score, win=win_rate)

        return EngineResponse(move=Move(uci=pr.move.uci(), san=self.board.san(pr.move)), score=score, win=win_rate)


def register(app: FastAPI):
    c = GameController()

    app.include_router(c.router)
