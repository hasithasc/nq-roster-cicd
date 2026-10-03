"""Roster assembly for the Student Roster API.

Pure Python with no Azure dependencies, so it unit tests locally in milliseconds.
All data is synthetic: learner IDs are DEMO-nnnn, the same convention the enrolment
integration uses, so the two demo segments read as one solution.
"""
from __future__ import annotations

ENROLLED = "ENROLLED"
DROPPED = "DROPPED"
WAITLISTED = "WAITLISTED"


class ClassNotFound(LookupError):
    """The requested class ID number does not exist."""


def mask_student_id(student_id: str) -> str:
    """DEMO-1030 -> DEMO-**30. Privacy by default (POPA)."""
    if len(student_id) <= 2:
        return "**"
    return student_id[:-4] + "**" + student_id[-2:]


def list_classes(seed: dict) -> list[dict]:
    """Every class the API knows about, for the demo's first screen."""
    return [{"classId": k, "className": v["name"], "term": v["term"]}
            for k, v in sorted(seed["classes"].items())]


def build_roster(seed: dict, class_id: str, *, mask_ids: bool = False,
                 max_size: int = 500) -> dict:
    """The roster for one class.

    mask_ids and max_size come from app settings, not from code: the same build
    behaves differently in Development and Production. See docs/SETUP.md.
    """
    cls = seed["classes"].get(class_id)
    if cls is None:
        raise ClassNotFound(class_id)

    rows = sorted((s for s in seed["students"] if s["classId"] == class_id),
                  key=lambda s: s["studentId"])[:max_size]
    students = [
        {"studentId": mask_student_id(s["studentId"]) if mask_ids else s["studentId"],
         "name": s["name"],
         "status": s["status"]}
        for s in rows
    ]
    return {"classId": class_id, "className": cls["name"], "term": cls["term"],
            "students": students}
