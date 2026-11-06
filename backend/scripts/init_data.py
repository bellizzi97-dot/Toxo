from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def create_data_folders() -> None:
    for folder in [ROOT / "data", ROOT / "data" / "knowledge", ROOT / "data" / "memory"]:
        folder.mkdir(parents=True, exist_ok=True)


def main() -> None:
    create_data_folders()
    print("Data folders ready.")


if __name__ == "__main__":
    main()
