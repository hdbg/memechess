import asyncio
import hashlib
import os
import subprocess
import time
import typing

import aiohttp

from evilfish.log import logger

API_URL = "https://auther.quarc.me/v1"
LOOP_WAIT = 60


class Protector:
    machine_id: str
    sub_end: str

    def __init__(self):
        raw = str(subprocess.check_output('wmic csproduct get uuid')).split('\\r\\n')[1].strip('\\r').strip()
        h = hashlib.sha256(bytes(raw.encode("ascii")))
        self.machine_id = h.hexdigest()[:32]

    async def validate(self) -> tuple[bool, str]:
        async with aiohttp.ClientSession() as client:
            response = await client.post(
                API_URL,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                data={"type": "auth", "public_token": config.APP_LICENSE_ID, "license": config.protector,
                      "hwid": self.machine_id})

            json = await response.json(content_type=None)

            status = json.get("Status")
            is_ok = status == "Activated" or status == "Authorized"

            if is_ok:
                self.sub_end = json.get("LicenseTime")

            return is_ok, status

    async def log(self, message: str, tag: typing.Optional[str] = None) -> bool:
        async with aiohttp.ClientSession() as client:
            response = await client.post(
                API_URL,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                data={"type": "log", "private_token": config.APP_PRIVATE_ID, "license": config.protector,
                      "message": message, "tag": tag})

            return "Success" in (await response.text())

    async def heartbeat(self):
        is_ok, _ = await self.validate()
        if is_ok:
            logger.info("protection.logged_in", time=self.sub_end)
            with open("./license", "w") as f:
                f.write(config.protector)

        while True:
            result, reason = await self.validate()

            if not result:
                logger.critical("protection.failed", reason=reason)

                time.sleep(20)

                os._exit(-1)

            await self.log("heartbeat", "heartbeat")
            await asyncio.sleep(LOOP_WAIT)


protector = Protector()
