import abc
import asyncio


class ProtocolInterface(metaclass=abc.ABCMeta):
    task: asyncio.Task = None

    @abc.abstractmethod
    async def run(self) -> asyncio.Task:
        raise NotImplementedError

    @abc.abstractmethod
    async def is_ready(self) -> bool:
        raise NotImplementedError

    async def kill(self):
        self.task.cancel()
