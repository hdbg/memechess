import asyncio

from evilfish.game import schemas
from evilfish.game.logic import game_logic
from fastapi import FastAPI
from hypercorn.asyncio import serve
from hypercorn.config import Config
from . import ProtocolInterface


class HttpTransport(ProtocolInterface):
    app = FastAPI()
    connected = False

    def __init__(self):
        super().__init__()
        self.app.add_api_route("/new", self.new_game, methods=["POST"])
        self.app.add_api_route("/push", self.push_move, methods=["POST"])

        self.app.add_api_route("/ping", self.ping)

    async def is_ready(self) -> bool:
        return self.connected

    async def run(self) -> asyncio.Task:
        c = Config()
        c.bind = ["localhost:4323"]
        c.loglevel = "ERROR"

        self.task = asyncio.create_task(serve(self.app, c))

        return self.task

    async def ping(self, req):
        print(req)
        return "Pong!"

    async def new_game(self, data: schemas.GameStartSchema):
        self.connected = True
        return await game_logic.new_game(data)

    async def push_move(self, data: schemas.GameMoveSchema):
        return await game_logic.push_move(data)


http = HttpTransport()
