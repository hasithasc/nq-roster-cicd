# End-to-end demonstration scenarios

These scenarios use the Student Roster API to demonstrate how staff safely change,
promote, validate and restore an integration. The same immutable artifact is promoted
Development → Test/UAT → Production. Environment settings change; application bits do not.

## Scenario matrix

| ID | Scenario | Evidence to show | Expected result |
|---|---|---|---|
| S01 | Developer runs the API locally | Unit-test output and local `/api/version` | All tests pass; environment is `Local` |
| S02 | Feature branch changes roster response | Branch, commit and linked work item | Change is traceable before deployment |
| S03 | Pull request validation | Ruff, pytest, Bicep compile and isolation checks | Merge is blocked until checks pass |
| S04 | Peer review and branch protection | Reviewer approval and protected `main` | Author cannot bypass review |
| S05 | Create immutable release tags | Automatic `rc-vX.Y.Z` and `vX.Y.Z` tags plus release notes | Successful deployments have durable identities |
| S06 | Deploy automatically to Development | Workflow job, `/api/version`, full learner IDs | New version is visible in Development |
| S07 | Reject a bad Development deployment | Failed smoke test and stopped dependency chain | Test and Production never start |
| S08 | Promote the same artifact to Test/UAT | Matching SHA-256 and commit across jobs | Test receives identical application bits |
| S09 | Test approval and UAT verification | Environment approval plus masked IDs | Business/technical validation is recorded |
| S10 | Production approval | Named approver, prevent-self-review control | Production waits for authorized approval |
| S11 | Production deployment | `/api/version`, masked IDs and smoke test | Approved release is live with Production config |
| S12 | Environment-specific configuration | Three parameter files side by side | Dev is unmasked; Test/Prod are masked |
| S13 | Authentication and least privilege | OIDC trust and one identity per environment | No stored Azure password; identities are isolated |
| S14 | Audit history | PR, tag, workflow summary, deployment history, Activity Log | Who/what/when/where is reconstructable |
| S15 | Controlled rollback | Rollback workflow, prior tag, incident reference, approval | Known-good tag is restored and verified |
| S16 | Rollback failure | Failed post-rollback smoke test | Run stays failed; incident remains open for escalation |
| S17 | Concurrent deployment protection | Workflow concurrency group | Releases cannot overtake each other |
| S18 | Unauthorized target protection | `guard-target.sh` failure | Pipeline refuses another resource group/app |
| S19 | Credential/configuration leak prevention | Isolation scan failure | Key-like strings block the pull request |
| S20 | Operational recovery after correction | Fixed test, new tag and normal promotion | Corrected release follows the same controls |

## Primary happy-path demonstration

1. Create branch `feature/ROSTER-14-enrolled-count`.
2. Implement the prepared change in `THE-CHANGE.md` and open a pull request.
3. Show automated tests and infrastructure checks, then obtain peer approval.
4. Merge to protected `main`; the push starts **Promote roster API**.
5. After Test/UAT succeeds, show the automatic `rc-vX.Y.Z` release candidate tag.
6. Show automatic Development deployment and its smoke-test evidence.
7. Approve Test/UAT, verify masked learner IDs and obtain business acceptance.
8. Approve Production using a different reviewer.
9. Verify `/api/version` reports the expected version/commit and the roster masks IDs.
10. Show the automatic Production `vX.Y.Z` tag and GitHub Release, then compare the
    SHA-256 value in all three job summaries to prove build-once/deploy-many.

## Defect and rollback demonstration

1. Deploy the deliberately incorrect `enrolledCount` implementation described in
   `THE-CHANGE.md`; it reports 10 although only 8 learners are enrolled.
2. Raise a sample record such as `INC-1007` and identify the last known-good tag.
3. Run **Roll back roster API** with `environment=production`, the known-good tag and
   the incident/change reference.
4. Show that rollback is also held behind the Production approval gate.
5. After approval, verify `/api/version` shows the restored commit and the old response
   contract has returned.
6. Show the rollback summary, approver, initiator, timestamp and Azure Activity Log.
7. Correct the requirement test and promote normally; successful deployments create the
   new Test/UAT and Production tags automatically.

## Failure scenarios to demonstrate or describe

### Pull-request test failure

Break the masking assertion. CI turns red and branch protection prevents merge. No Azure
authentication occurs in PR validation.

### Development smoke-test failure

Change `ENVIRONMENT_NAME` in the Dev parameter file to an unexpected value. The real URL
does not match the expected environment, so the Dev job fails and downstream jobs remain
blocked.

### Approval rejected or timed out

Reject the Test or Production review. The application remains on its current version and
the rejected request remains in the environment deployment history.

### Incorrect Azure target

Set `AZURE_RESOURCE_GROUP` to a name outside `rg-nqcicd-{dev|test|prod}-cc`. The guard
fails before Azure login or any write operation.

### OIDC trust mismatch

Use a federated credential subject that does not match the GitHub Environment. Azure
rejects the short-lived token; no fallback password exists. Correct the subject and rerun.

### Production health failure

If Production deployment succeeds but smoke testing fails, stop promotion activity,
create an incident, and run the rollback workflow using the last known-good tag. Do not
rerun the failed new release as a recovery action.

## Audit evidence checklist

- Work item and pull-request URL
- Commit SHA and peer-review decision
- Required status-check results
- Release tag and generated release notes
- Artifact SHA-256
- Development, Test and Production deployment records
- Environment approver and requester identities
- Smoke-test result from the deployed URL
- Azure deployment name and Activity Log event
- Rollback tag and incident/change reference, if used
