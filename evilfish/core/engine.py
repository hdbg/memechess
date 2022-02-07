import chess
import chess.engine
from chess.engine import EngineTerminatedError
from evilfish.core import consts
from evilfish.core import utils
from evilfish.log import logger


class Engine:
    _worker: chess.engine.Protocol

    async def load(self):
        bin_path = utils.get_file_path(consts.APP_ENGINE_FILE)

        _, self._worker = await chess.engine.popen_uci(bin_path)
        logger.debug("engine.opts", opts=self._worker.options)
        logger.info("engine.booted")

    async def play(self, b: chess.Board, limit: chess.engine.Limit) -> chess.engine.PlayResult:
        try:
            pr = await self._worker.play(b, limit, info=chess.engine.INFO_SCORE)

            return pr
        except EngineTerminatedError:
            logger.error("engine.crash")
            await self.load()
            await self.play(b, limit)

    async def analyse(self, b: chess.Board, limit: chess.engine.Limit) -> dict:
        try:
            pr = await self._worker.analyse(b, limit, info=chess.engine.INFO_SCORE)

            return pr
        except EngineTerminatedError:
            logger.error("engine.crash")
            await self.load()
            await self.analyse(b, limit)


engine = Engine()
