import typing

from fastapi import APIRouter


class BaseController:
    router = APIRouter()

    def json(self, event_type: str, data: typing.Optional[dict] = {}):
        return {"status": "ok", "event": event_type, "data": data}

    def error(self, event_type: str, message: str):
        return {"status": "error", "event": event_type, "message": message}
