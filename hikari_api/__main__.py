from __future__ import annotations

import uvicorn

from hikari_api.config import load_config


def main() -> None:
    config = load_config()
    uvicorn.run(
        "hikari_api.app:app",
        host=config.server.host,
        port=config.server.port,
        reload=False,
    )


if __name__ == "__main__":
    main()
