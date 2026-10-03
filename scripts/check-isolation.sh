#!/usr/bin/env bash
# Fails the build if this repository has grown a reference to another project's Azure
# resources, or to a region outside Canada.
#
# This runs on every pull request and on every deployment. It is a cheap, permanent
# guard against the most likely accident: copying a command or a parameter from the
# enrolment-integration demo that shares this Azure subscription.
set -uo pipefail

SELF="$(basename "$0")"
fail=0

# Resource-name fragments that belong to the OTHER demo segment, or to no project here.
# Deliberately generic: this repository has no business naming another project's resources.
FORBIDDEN_PATTERNS=(
  'rg-nqdemo'
  'nqdemo-dev'
  'func-enrol'
  'func-mockmoodle'
  'apim-nqdemo'
  'sb-nqdemo'
  'kv-nqdemo'
  'appi-nqdemo'
  'log-nqdemo'
  'la-nqdemo'
  'enrolmentstatus'
  'mockmoodleenrolments'
)

for pat in "${FORBIDDEN_PATTERNS[@]}"; do
  hits="$(grep -rniI --exclude-dir=.git --exclude="$SELF" -e "$pat" . || true)"
  if [[ -n "$hits" ]]; then
    echo "::error::This repository must not reference another project's Azure resources. Found '$pat':"
    echo "$hits"
    fail=1
  fi
done

# Every parameter file must stay in Canada and must use this project's own identity.
for f in infra/*.parameters.json; do
  loc="$(grep -o '"location"[^}]*' "$f" | grep -o 'canada[a-z]*' || true)"
  if [[ -z "$loc" ]]; then
    echo "::error::$f does not pin location to a Canadian region."
    fail=1
  fi
  if ! grep -q '"value": *"id-roster-deploy-' "$f"; then
    echo "::error::$f does not use this project's own managed identity (id-roster-deploy-*)."
    fail=1
  fi
done

# A connection string or key pasted into the repository is always a mistake.
if grep -rniI --exclude-dir=.git --exclude="$SELF" -e 'Ocp-Apim-Subscription-Key' \
     -e 'AccountKey=' -e 'SharedAccessKey' -e 'x-functions-key' . >/dev/null 2>&1; then
  echo "::error::A credential-looking string is present in this repository. Remove it."
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo "Isolation check passed: this repository references only its own resources."
fi
exit $fail
