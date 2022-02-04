from pydantic import BaseModel, Field


class FishConfig(BaseModel):
    lic_key: str = Field("")


fish_config = None
