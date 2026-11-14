from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

PROJECT_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=PROJECT_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Image Processor"
    storage_root: Path = PROJECT_ROOT / "storage"
    rabbitmq_url: SecretStr
    exchange_name: str = "image-exchange"
    queue_name: str = "image-jobs"
    routing_key: str = "image.process"

    @property
    def upload_directory(self) -> Path:
        root = self.storage_root.expanduser()
        if not root.is_absolute():
            root = PROJECT_ROOT / root
        return root / "uploads"
