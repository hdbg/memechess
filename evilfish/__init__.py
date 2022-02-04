import os
import shutil
import types
import typing

from evilfish.core import engine, consts, utils
from evilfish.core.protection import protector
from evilfish.log import logger
from evilfish.proto import ProtocolInterface

from rich.console import Console

class EvilFish:
    console = Console()

    state: types.SimpleNamespace
    debug: bool

    connector: typing.Type[ProtocolInterface]

    def boot(self):
        with self.console.status("[green]Booting"):


            self.load_files()

    def load_files(self):
        if not os.path.exists(consts.APP_MAIN_FOLDER):
            os.mkdir(consts.APP_MAIN_FOLDER)

        if not os.path.exists(consts.APP_ENGINE_FILE):
            shutil.copy(utils.get_file_path("files/engine.exe"), consts.APP_ENGINE_FILE)

        # if not os.path.exists(consts.APP_STRATEGIES_FOLDER):
        #     os.mkdir(consts.APP_STRATEGIES_FOLDER)
        #     shutil.copy(utils.get_file_path(utils.get_file_path("files\\strategy.json")), consts.APP_ENGINE_FILE)


fish = EvilFish()
