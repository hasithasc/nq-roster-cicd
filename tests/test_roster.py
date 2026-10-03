"""Unit tests for the roster logic. These run on every pull request and block the merge."""
import pytest
from shared.roster import ClassNotFound, build_roster, list_classes, mask_student_id

HCA1010 = "2271-HCA1010-01"


def test_lists_every_class(seed):
    classes = list_classes(seed)
    assert len(classes) == 3
    assert {c["classId"] for c in classes} == {
        "2271-HCA1010-01", "2271-HCA1020-01", "2271-PN1100-01"}


def test_roster_returns_the_class_details(seed):
    r = build_roster(seed, HCA1010)
    assert r["classId"] == HCA1010
    assert r["className"] == "Health Care Aide: Foundations"
    assert r["term"] == "2271"


def test_roster_returns_every_student_in_the_class(seed):
    r = build_roster(seed, HCA1010)
    assert len(r["students"]) == 10
    assert all(s["classId"] != HCA1010 for s in seed["students"]
               if s["studentId"] not in {x["studentId"] for x in r["students"]})


def test_roster_is_sorted_by_student_id(seed):
    ids = [s["studentId"] for s in build_roster(seed, HCA1010)["students"]]
    assert ids == sorted(ids)


def test_unknown_class_raises(seed):
    with pytest.raises(ClassNotFound):
        build_roster(seed, "2271-NOPE9999-01")


def test_student_ids_are_masked_when_the_setting_is_on(seed):
    r = build_roster(seed, HCA1010, mask_ids=True)
    assert r["students"][0]["studentId"] == "DEMO-**01"
    assert all("**" in s["studentId"] for s in r["students"])


def test_student_ids_are_not_masked_when_the_setting_is_off(seed):
    r = build_roster(seed, HCA1010, mask_ids=False)
    assert r["students"][0]["studentId"] == "DEMO-1001"


def test_max_size_caps_the_roster(seed):
    r = build_roster(seed, HCA1010, max_size=3)
    assert len(r["students"]) == 3


def test_masking_helper():
    assert mask_student_id("DEMO-1030") == "DEMO-**30"
    assert mask_student_id("X") == "**"
