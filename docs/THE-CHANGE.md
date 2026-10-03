# The change you take through the pipeline

Do not improvise a code change on stage. This is the one, prepared, four-line change that
the whole 15 minutes is built around. Have it ready as a branch you can push, or typed
into a second editor window ready to paste.

## The work item

> **ROSTER-14** — The Registrar's office wants the class roster to show a headcount, so
> advisors don't have to count rows when they're on the phone with a student.

Small, obviously reasonable, and something nobody in the room will question.

## The change

In `src/roster_api/shared/roster.py`, at the end of `build_roster`, replace the return
statement with:

```python
    return {"classId": class_id, "className": cls["name"], "term": cls["term"],
            "students": students,
            "enrolledCount": len(students)}
```

And add this test to `tests/test_roster.py`:

```python
def test_roster_includes_an_enrolled_count(seed):
    r = build_roster(seed, HCA1010)
    assert r["enrolledCount"] == len(r["students"])
```

Commit message:

```
ROSTER-14: add enrolledCount to the roster response

The Registrar's office asked for a headcount so advisors do not have to
count rows. Adds enrolledCount alongside the existing students array.
```

## The bug, and why it is there on purpose

`len(students)` counts **every** student on the roster, including the ones who dropped and
the one who is waitlisted. For class `2271-HCA1010-01` the seed data holds 10 students: 8
ENROLLED, 1 DROPPED, 1 WAITLISTED.

So the API will report `"enrolledCount": 10` when the true answer is **8**.

And the test passes. It asserts the field equals the length of the array — which is exactly
what the code does. It is a test of the implementation rather than of the requirement, and
that is the most common way a real defect walks through a green pipeline.

Everything downstream stays green too: the production smoke test checks for HTTP 200, the
right commit, the right environment and the masking rule. It does not know what the count
should be. So the change is approved, promoted, and live — and wrong.

## What you say when you catch it

> "That says ten. There are eight students enrolled in that class; one dropped and one is
> waitlisted. The pipeline did everything we asked it to — it ran the tests, it got a
> human approval, it deployed the same artifact we tested. The gate is only ever as good
> as the test behind it. What the pipeline actually bought us is this: I can put the
> previous version back right now, in front of you, and fix the test properly tomorrow."

Then roll back. That sentence is worth more to an evaluation panel than a flawless happy
path, because every one of them has lived it.

## The fix, if you have time at the end (optional, about 60 seconds)

The correct assertion, which fails against the buggy code:

```python
def test_enrolled_count_excludes_dropped_and_waitlisted(seed):
    r = build_roster(seed, HCA1010)
    expected = sum(1 for s in r["students"] if s["status"] == "ENROLLED")
    assert r["enrolledCount"] == expected      # 8, not 10
```

and the corrected line:

```python
            "enrolledCount": sum(1 for s in students if s["status"] == ENROLLED)}
```

Only show this if you are comfortably ahead of time. Running out of clock mid-fix is worse
than not starting it — the rollback is already a complete ending.
