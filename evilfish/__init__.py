import asyncio
import os
import shutil
import typing

import aiohttp
from evilfish.core import engine, consts, utils
from evilfish.core.engine import engine
from evilfish.core.protection import protector
from evilfish.log import logger
from evilfish.proto import ProtocolInterface
from evilfish.proto import http, ws, emu
from evilfish.strategies import strategy_manager
from rich.console import Console
from rich.progress import Progress


class EvilFish:
    console = Console()

    connector: ProtocolInterface

    def boot(self):
        self.load_files()

        asyncio.run(self.main())

    def load_files(self):
        if not os.path.exists(consts.APP_MAIN_FOLDER):
            os.mkdir(consts.APP_MAIN_FOLDER)

        if not os.path.exists(consts.APP_STRATEGIES_FOLDER):
            os.mkdir(consts.APP_STRATEGIES_FOLDER)
            # shutil.copy(utils.get_file_path(utils.get_file_path("files\\strategy.json")), consts.APP_STRATEGIES_FOLDER)

        strategy_manager.load()

    async def main(self):
        await self.download_engine()
        await engine.load()

        # TEST
        from evilfish.game.logic import game_logic
        from evilfish.game import schemas

        from evilfish.game.types import Variant
        import chess
        await game_logic.new_game(schemas.GameStartSchema(variant=Variant.standard, player_side=chess.WHITE, id="kek", history=[]))
        await game_logic._query_engine(schemas.GameMoveSchema(white_clock=None, black_clock=None, move="a2a4"))

        # END

        await self.run()



        await self.connector.task

    async def run(self) -> bool:
        proto_instances: typing.List[ProtocolInterface] = [http.http]

        for inst in proto_instances:
            await inst.run()

        while True:
            for inst in proto_instances:
                try:
                    await asyncio.wait_for(asyncio.shield(inst.task), timeout=5)
                except asyncio.TimeoutError:
                    pass

                if (await inst.is_ready()):
                    self.connector = inst

                    logger.info("ready")

                    return True

    async def download_engine(self):
        async with aiohttp.ClientSession() as session:
            releases = await session.get("https://api.github.com/repos/ianfab/Fairy-Stockfish/releases",
                                         params={"page": 1, "per_page": 1},
                                         headers={"accept": "application/vnd.github.v3+json"})

            download_link = None

            for binary in (await releases.json())[0].get("assets"):
                if binary.get("name") == "fairy-stockfish-largeboard_x86-64.exe":
                    download_link = binary.get("browser_download_url")
                    break

            if not download_link:
                logger.fatal("engine.download_failed")
                # pprint((await releases.json())[0].get("assets"))
                return

            CHUNK_SIZE = 1024

            with Progress() as progress:
                engine_release = await session.get(download_link)

                dw_task = progress.add_task("[green]Downloading engine")
                file = open(consts.APP_ENGINE_FILE, "wb")

                downloaded_bytes = 0
                total_size = engine_release.headers.get("Content-Length")

                async for chunk in engine_release.content.iter_chunked(CHUNK_SIZE):
                    file.write(chunk)

                    downloaded_bytes += CHUNK_SIZE
                    progress.update(dw_task, completed=(downloaded_bytes / int(total_size)) * 100)


fish = EvilFish()
