# Student Roster API — CI/CD demo segment

A small Azure Function App that exists so a 15-minute demo can answer one question:
**how would college staff promote an integration from Development through Test/UAT into Production, and roll it
back if it turns out to be wrong?**

It covers testing, approvals, environment-specific configuration, version control and audit
history. It is the CI/CD segment of a larger demo; the integration itself is a separate
piece of work in a separate resource group.

> ### Before you touch anything, read [`docs/ISOLATION-RULES.md`](docs/ISOLATION-RULES.md).
> This project shares an Azure subscription with another presenter's demo. Two scripts in
> `scripts/` enforce the boundary, and both run in CI.

## What it does

| Endpoint | Purpose |
|---|---|
| `GET /api/health` | Liveness |
| `GET /api/version` | Which build is live, and in which environment. **The demo's proof instrument** |
| `GET /api/classes` | The classes this API knows about |
| `GET /api/classes/{classId}/roster` | The students in one class |

Data is a seeded JSON file — nineteen invented learners across three classes. No real
student information, no external dependency, nothing to break on demo day.

`/api/version` reports values stamped by the deployment pipeline, so it cannot disagree
with what was actually deployed. It is how a promotion and a rollback become visible in one
second instead of asserted.

## Documentation, in reading order

| File | What it is |
|---|---|
| [`docs/ISOLATION-RULES.md`](docs/ISOLATION-RULES.md) | The boundary with the other demo segment, and how it is enforced |
| [`docs/SETUP.md`](docs/SETUP.md) | One-time setup: resource groups, managed identities, federated credentials, GitHub Environments. Start with Step 0 |
| [`docs/THE-CHANGE.md`](docs/THE-CHANGE.md) | The prepared four-line change that travels the pipeline, and the bug it carries on purpose |
| [`docs/SCENARIOS.md`](docs/SCENARIOS.md) | Twenty happy-path, approval, failure, security, audit and rollback scenarios |
| [`docs/RUN-OF-SHOW.md`](docs/RUN-OF-SHOW.md) | The 15 minutes, minute by minute, including what to pre-stage |

## Run it locally

```bash
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r src/roster_api/requirements.txt pytest ruff
pytest                      # 9 tests, well under a second
ruff check .
bash ./scripts/check-isolation.sh
```

To run the app itself you need [Azure Functions Core Tools]:

```bash
cd src/roster_api
func start
curl http://localhost:7071/api/classes/2271-HCA1010-01/roster
```

[Azure Functions Core Tools]: https://learn.microsoft.com/azure/azure-functions/functions-run-local

## Repository layout

```
.github/workflows/ci.yml       Pull-request gate: lint, tests, Bicep validation, isolation check
.github/workflows/deploy.yml   Build once, promote through Development, Test/UAT and Production
.github/workflows/deploy-environment.yml  Reusable guarded environment deployment
.github/workflows/release.yml  Test and create an immutable semantic release tag
.github/workflows/rollback.yml Restore a known-good tag through the protected environment
.github/CODEOWNERS             Who must review (replace the placeholder)
src/roster_api/                The Function App
  function_app.py              HTTP routes
  shared/roster.py             Roster logic - pure Python, no Azure, unit testable
  data/roster-seed.json        Synthetic data
tests/                         Unit tests
infra/main.bicep               All infrastructure for one environment, self-contained
infra/*.parameters.json        Separate Development, Test/UAT and Production settings
scripts/guard-target.sh        Refuses any deployment target that is not this project's
scripts/check-isolation.sh     Refuses another project's resource names in this repository
scripts/smoke-test.sh          Post-deployment verification against the real URL
```

## Design decisions worth knowing

**Flex Consumption, Python 3.12.** The current plan for new Function Apps. It has **no
deployment slots**, so there is no blue/green swap — the documented recovery path is to
re-run the last successful pipeline run, which is what the demo shows. That is a feature of
this story rather than a gap in it: the rollback is a CI/CD capability, not an Azure one.

**Build once, deploy many.** One build job produces one artifact; all three environments
deploy that artifact. Production never gets a rebuild, so the bits in production are the
bits that passed in Test/UAT.

**OIDC, not stored credentials.** No publish profile and no Azure password in GitHub. The
pipeline exchanges a short-lived GitHub token for an Azure one, and Azure only trusts it
from this repository, for a named environment.

**One managed identity per environment.** The Development and Test identities cannot write
to the Production resource group. Separation is enforced by capability, not convention.

**Explicit rollback.** The rollback workflow accepts only an immutable semantic release
tag, requires an incident/change reference, passes through the target environment approval
and verifies the restored application using the live endpoints.

**Anonymous HTTP auth.** Every URL here gets read on screen during the demo, and a function
key in a visible URL would be worse than exposing invented data. In the real solution this
sits behind API Management with a subscription key. The compensating control is
`MASK_STUDENT_IDS`, which is on in production.

## Verified

Unit tests and lint pass; `infra/main.bicep` compiles with Bicep CLI 0.47.16; both guard
scripts were tested against valid and invalid targets. The workflows have not been executed
against a live Azure subscription — do that during Step 8 of `docs/SETUP.md` and allow time
for the federated-credential step to need a second attempt.
