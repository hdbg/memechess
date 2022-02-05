import structlog
import sys
logger = structlog.get_logger("EvilFish Logger")


def excp_handler(ex_type, exception, traceback):
    logger.exception("error")

sys.excepthook = excp_handler