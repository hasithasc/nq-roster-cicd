#!/usr/bin/env bash
# Post-deployment smoke test. Runs against the real URL after every deployment and
# fails the job if the deployment did not do what it claimed.
#
# Usage: smoke-test.sh <base-url> <expected-commit> <expected-environment> <expect-masking true|false>
set -euo pipefail

BASE="${1%/}"
EXPECT_COMMIT="$2"
EXPECT_ENV="$3"
EXPECT_MASKED="$4"
CLASS="2271-HCA1010-01"

echo "Smoke testing $BASE"

# A Flex Consumption app that has just been deployed may still be starting.
for i in $(seq 1 12); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/health" || true)"
  [[ "$code" == "200" ]] && break
  echo "  waiting for the app to answer (attempt $i, last status $code)"
  sleep 5
done
[[ "$code" == "200" ]] || { echo "::error::/api/health never returned 200 (last: $code)"; exit 1; }
echo "  health OK"

ver="$(curl -fsS "$BASE/api/version")"
echo "  version endpoint: $ver"
got_commit="$(echo "$ver" | python3 -c 'import json,sys;print(json.load(sys.stdin)["commit"])')"
got_env="$(echo "$ver" | python3 -c 'import json,sys;print(json.load(sys.stdin)["environment"])')"

[[ "$got_commit" == "$EXPECT_COMMIT" ]] || {
  echo "::error::Wrong build is live. Expected commit $EXPECT_COMMIT, the app reports $got_commit."; exit 1; }
[[ "$got_env" == "$EXPECT_ENV" ]] || {
  echo "::error::Wrong environment configuration. Expected $EXPECT_ENV, the app reports $got_env."; exit 1; }
echo "  correct build and environment confirmed"

roster="$(curl -fsS "$BASE/api/classes/$CLASS/roster")"
python3 - "$roster" "$EXPECT_MASKED" <<'PY'
import json, sys
body = json.loads(sys.argv[1])
expect_masked = sys.argv[2].lower() == "true"
students = body["students"]
assert len(students) == 10, f"expected 10 students on the roster, got {len(students)}"
masked = all("**" in s["studentId"] for s in students)
if expect_masked and not masked:
    raise SystemExit("learner IDs are NOT masked, but this environment requires masking")
if not expect_masked and masked:
    raise SystemExit("learner IDs are masked, but this environment does not expect masking")
print(f"  roster OK: {len(students)} students, masking={'on' if masked else 'off'}")
PY

echo "Smoke test passed."
