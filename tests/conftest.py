import json
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src" / "roster_api"))

SEED_PATH = ROOT / "src" / "roster_api" / "data" / "roster-seed.json"


@pytest.fixture(scope="session")
def seed() -> dict:
    return json.loads(SEED_PATH.read_text(encoding="utf-8"))
