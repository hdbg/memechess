import asyncio

from evilfish.core import consts
from evilfish import fish
from evilfish.log import console

console.print(consts.LOGO, style="magenta")
fish.boot()