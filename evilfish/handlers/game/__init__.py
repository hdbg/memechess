from fastapi import FastAPI

from . import controller


def register(app: FastAPI):
    controller.register(app)
