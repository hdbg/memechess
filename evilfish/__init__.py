import asyncio

import chess.engine

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.responses import ORJSONResponse

from hypercorn.asyncio import serve
from hypercorn.config import Config

from evilfish import utils
from evilfish.core.engine import engine
from evilfish.core.log import logger
from evilfish.core.protection import protector

from evilfish.handlers import game
from evilfish.config import config


# pp.mount("/files", StaticFiles(directory=utils.get_file_path("files")), name="files")

class EvilFish:
    app = FastAPI(title="EvilFish", default_response_class=ORJSONResponse)

    def _debug_detect(self):
        # try:
        #     t = __compiled__
        #
        #     config.debug = False
        # except NameError:
        #     config.debug = True
        #     logger.info("debug")
        config.debug = False

    def __init__(self):
        self._debug_detect()

        @self.app.on_event("startup")
        async def startup_event():
            if not config.debug:
                asyncio.create_task(protector.heartbeat())

            await engine.load()

            logger.info("server.ready")

        self.app.add_api_route("/files/{name}", self.static)

        game.register(self.app)

    async def static(self, name: str):
        return FileResponse(utils.get_file_path(f"files\\{name}"))

    def run(self):
        logger.info("server.booting")
        asyncio.set_event_loop_policy(chess.engine.EventLoopPolicy())

        c = Config()
        c.bind = ["localhost:8080"]
        c.loglevel = "ERROR"

        asyncio.run(serve(self.app, c))


fish = EvilFish()
