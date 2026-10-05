# Student Roster API — CI/CD demo segment

This project is a deliberately small Azure Function App designed to show how a team can move changes from Development to Test/UAT and then to Production, while also proving how to roll back when something goes wrong.

The application is intentionally simple: it serves synthetic student roster data, exposes environment-specific metadata, and demonstrates modern CI/CD practices without depending on real student data or a complex backend.

## Why this repo exists

The core question this demo answers is:

How do we promote a change safely through multiple environments and recover quickly if the promoted version is wrong?

This repo covers:

- automated validation on pull requests
- environment-specific configuration
- controlled approvals before deployment
- immutable release tags
- explicit rollback steps
- proof that the deployed version matches the code shipped

This is the CI/CD portion of a larger demo. The enrollment or integration work is intentionally separated into a different resource group and is not part of this app.

## What the app does

| Endpoint | Purpose |
|---|---|
| `GET /api/health` | Liveness check |
| `GET /api/version` | Shows which build is live and in which environment. This is the demo’s proof instrument. |
| `GET /api/classes` | Lists all classes the API knows about |
| `GET /api/classes/{classId}/roster` | Returns the students in a specific class |

The data comes from a seeded JSON file containing synthetic learners across a few classes. No real personal information is used and there are no external dependencies.

The most important endpoint is `/api/version`. It reports values stamped during deployment, so it cannot disagree with what was actually deployed. In practice, this makes promotion and rollback visible in a single glance instead of relying on manual assertions.

## Architecture at a glance

This project combines a small API with a GitHub Actions-based delivery pipeline:

1. Code is written and tested locally.
2. Pull requests trigger validation in CI.
3. A build artifact is produced once and reused.
4. The same artifact is promoted through Development, Test/UAT, and Production.
5. The app reports version metadata so the team can confirm which build is truly live.
6. Rollback is handled as a deliberate, tracked action using a known-good release tag.

## Quick start

### Local Python checks

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate

pip install -r src/roster_api/requirements.txt pytest ruff
pytest
ruff check .
bash ./scripts/check-isolation.sh
```

### Run the app locally

You need the Azure Functions Core Tools installed first.

```bash
cd src/roster_api
func start
curl http://localhost:7071/api/classes/2271-HCA1010-01/roster
```

## Project layout

```text
.github/
  workflows/
    ci.yml                     Pull request gate: lint, tests, Bicep validation, isolation checks
    deploy.yml                 Build once and promote across environments
    deploy-environment.yml     Reusable guarded deployment workflow
    release.yml                Create an immutable semantic release tag
    rollback.yml               Restore a known-good build to a protected environment
  CODEOWNERS                  Required reviewers for the repository

src/
  roster_api/
    function_app.py           Azure Function routes and environment handling
    host.json                 Azure Functions host configuration
    requirements.txt          Python dependencies
    data/
      roster-seed.json        Synthetic roster data
    shared/
      roster.py               Pure Python roster logic, unit-testable without Azure

tests/
  conftest.py                 Shared test fixtures
  test_roster.py             Unit tests for roster logic and masking

infra/
  main.bicep                 Infrastructure for one environment
  *.parameters.json          Development, Test/UAT, and Production settings

scripts/
  check-isolation.sh          Verifies the deployment target is the correct project
  guard-target.sh            Refuses deployments that do not match this repository’s boundary
  smoke-test.sh              Verifies the deployed app responds as expected

README.md                    This file
pytest.ini                   Pytest configuration
ruff.toml                    Lint configuration
```

## Documentation in reading order

| File | Purpose |
|---|---|
| [docs/SETUP.md](docs/SETUP.md) | One-time setup: resource groups, managed identities, federated credentials, and GitHub environments |
| [docs/THE-CHANGE.md](docs/THE-CHANGE.md) | A small, intentional bug that travels through the promotion pipeline |
| [docs/SCENARIOS.md](docs/SCENARIOS.md) | Happy-path, approval, failure, security, and rollback scenarios |
| [docs/RUN-OF-SHOW.md](docs/RUN-OF-SHOW.md) | A 15-minute demo plan and pre-stage checklist |

## Design decisions worth knowing

### Flex Consumption + Python 3.12

This repo uses the modern Azure Functions Flex Consumption model with Python 3.12. It does not rely on deployment slots, so the recovery path is built around re-running a known-good deployment rather than a blue/green swap. That is intentional and is part of the demo story.

### Build once, deploy many

One build produces one artifact, and that artifact is promoted through each environment. Production is not rebuilt from scratch; it receives the same validated bits that already passed through Test/UAT.

### OIDC instead of stored credentials

The pipeline uses short-lived GitHub OIDC credentials to authenticate with Azure. There is no stored publish profile or long-lived Azure password in GitHub.

### One managed identity per environment

Each environment has a dedicated managed identity with restricted access. Development and Test cannot write to the Production resource group, which enforces separation by capability rather than by convention.

### Explicit rollback

Rollback is not a hidden action. It requires a valid semantic release tag, a reason or incident reference, environment approval, and a live verification check after restore.

### Anonymous HTTP access for demo purposes

These endpoints are intentionally public for demonstration. In a production system, they would normally sit behind API Management. To reduce privacy risk, the app masks student IDs in production by setting `MASK_STUDENT_IDS`.

## Verification status

The repository is set up so that lint, unit tests, and infrastructure validation are enforced in CI. The code and templates are designed to be checked automatically before any promotion is allowed.

> The workflows are not executed against a live Azure subscription in this repository itself; that step is part of the setup process documented in [docs/SETUP.md](docs/SETUP.md).

## Summary

This is a compact but realistic example of how a team can demonstrate safe delivery and fast recovery using Azure Functions, GitHub Actions, environment separation, and clear deployment evidence. The app itself is intentionally simple, but the operational patterns are the focus.
