#!/usr/bin/env bash
# Refuses any deployment target that is not a Student Roster API resource.
#
# WHY THIS EXISTS: this demo shares an Azure subscription with a separate integration
# demo that belongs to someone else. A mistyped resource-group variable, a copied
# command, or a pasted parameter file must never be able to deploy into, overwrite or
# reconfigure that other project. This script runs BEFORE any az command that writes,
# and again after Bicep reports the name it created.
#
# Usage: guard-target.sh <resource-group> [function-app-name]
set -uo pipefail

RG="${1:-}"
APP="${2:-}"

RG_PATTERN='^rg-nqcicd-(dev|test|prod)-cc$'
APP_PATTERN='^func-roster-nqcicd-(dev|test|prod)-[a-z0-9]{6}$'

fail() {
  # The ::error:: prefix makes this show up as a red annotation on the Actions run.
  echo "::error::$1"
  echo
  echo "This pipeline is only ever allowed to deploy to:"
  echo "    resource groups  rg-nqcicd-{dev|test|prod}-cc"
  echo "    function apps    func-roster-nqcicd-{dev|test|prod}-<6 chars>"
  echo
  echo "If you meant to deploy somewhere else, you are in the wrong repository."
  exit 1
}

[[ -n "$RG" ]] || fail "No resource group was supplied. Set the AZURE_RESOURCE_GROUP variable on this GitHub Environment."

if [[ ! "$RG" =~ $RG_PATTERN ]]; then
  fail "Resource group '$RG' is not a Student Roster API resource group."
fi

if [[ -n "$APP" && ! "$APP" =~ $APP_PATTERN ]]; then
  fail "Function app '$APP' is not a Student Roster API function app."
fi

echo "Target check passed: resource group '$RG'${APP:+, function app '$APP'}"
