"""Student Roster API - the sample Function App for the CI/CD demo segment.

Endpoints
  GET /api/health                     liveness
  GET /api/version                    which build is live, and in which environment
  GET /api/classes                    the classes this API knows about
  GET /api/classes/{classId}/roster   the students in one class

Why anonymous auth: every URL here is read on screen during the demo, and putting a
function key in a visible URL is worse than exposing synthetic data. In the real
solution this sits behind API Management with a subscription key - see the enrolment
integration segment. The compensating control here is MASK_STUDENT_IDS, which is
true in Production.

All data is synthetic. No real student information exists in this repository.
"""
from __future__ import annotations

import json
import logging
import os
import pathlib

import azure.functions as func
from shared.roster import ClassNotFound, build_roster, list_classes

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

SEED_PATH = pathlib.Path(__file__).parent / "data" / "roster-seed.json"
_seed: dict | None = None
log = logging.getLogger("nq.roster")


def seed() -> dict:
    global _seed
    if _seed is None:
        _seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    return _seed


def _flag(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in ("1", "true", "yes", "on")


def _env(name: str = "ENVIRONMENT_NAME") -> str:
    return os.getenv(name, "Local")


def _json(body: dict | list, status: int = 200) -> func.HttpResponse:
    return func.HttpResponse(json.dumps(body), status_code=status,
                             mimetype="application/json")


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    return _json({"status": "healthy", "environment": _env()})


@app.route(route="version", methods=["GET"])
def version(req: func.HttpRequest) -> func.HttpResponse:
    """The demo's proof instrument: this is how you SEE a promotion and a rollback.

    Every value comes from an app setting stamped by the deployment pipeline, so it
    cannot drift from what was actually deployed.
    """
    return _json({
        "service": "roster-api",
        "version": os.getenv("APP_VERSION", "0.0.0-local"),
        "commit": os.getenv("GIT_COMMIT", "local"),
        "environment": _env(),
        "builtUtc": os.getenv("BUILD_UTC", ""),
    })


@app.route(route="classes", methods=["GET"])
def classes(req: func.HttpRequest) -> func.HttpResponse:
    return _json({"classes": list_classes(seed())})


@app.route(route="classes/{classId}/roster", methods=["GET"])
def roster(req: func.HttpRequest) -> func.HttpResponse:
    class_id = req.route_params["classId"]
    try:
        body = build_roster(seed(), class_id,
                            mask_ids=_flag("MASK_STUDENT_IDS"),
                            max_size=int(os.getenv("MAX_ROSTER_SIZE", "500")))
    except ClassNotFound:
        log.warning("ROSTER_NOT_FOUND class=%s env=%s", class_id, _env())
        return _json({"classId": class_id, "error": "class not found"}, 404)
    log.info("ROSTER class=%s students=%d env=%s", class_id, len(body["students"]), _env())
    return _json(body)
