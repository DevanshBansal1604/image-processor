from pathlib import PurePosixPath
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ResizeOperation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Literal["resize"]
    width: int = Field(gt=0, strict=True)
    height: int = Field(gt=0, strict=True)


class ImageJob(BaseModel):
    """Version 1 ticket contract, not an upload endpoint or a publisher."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal[1]
    job_id: UUID
    stored_file: str = Field(min_length=1)
    content_type: Literal["image/jpeg", "image/png", "image/webp"]
    operation: ResizeOperation

    @field_validator("stored_file")
    @classmethod
    def require_relative_reference(cls, value: str) -> str:
        path = PurePosixPath(value)
        if (
            path.is_absolute()
            or not path.parts
            or ".." in path.parts
            or "\\" in value
            or ":" in value
            or "\x00" in value
        ):
            raise ValueError("stored_file must be a relative POSIX file reference")
        return value
