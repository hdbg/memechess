import logging

import structlog
import sys

from rich.console import Console

console = Console()
logger = structlog.get_logger("EvilFish Logger")


# logging.basicConfig(level=logging.DEBUG)