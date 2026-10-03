# Read this first: staying out of the other demo segment

This CI/CD segment runs in the **same Azure subscription** as a separate integration demo
that belongs to another presenter. That demo is the one the panel sees before yours, and
its live resources, telemetry and cost views are all evidence he has already captured.

Breaking it is the one unrecoverable mistake available to you. Everything below exists to
make that difficult rather than merely discouraged.

## The four rules

**1. Your own resource groups, and only those three.**

    rg-nqcicd-dev-cc        Development
    rg-nqcicd-test-cc       Test/UAT
    rg-nqcicd-prod-cc       Production

Both in Canada Central. Create nothing outside them. The deployment pipeline refuses any
other target — see *How this is enforced* below.

**2. Never deploy to the other presenter's personal subscription.** Ask him which
subscription the demo runs on and use that one. His *personal* subscription is where every
cost screenshot in his segment comes from; a second project's resources appearing in it
would invalidate figures he has already measured and presented.

**3. Your own Application Insights and Log Analytics workspace.** `infra/main.bicep`
creates both, inside your resource group. Do not point this project at an existing
workspace. If you did, your traffic would appear in his queries and start consuming the
daily ingestion cap he is using as evidence of cost control.

**4. Role assignments scoped to your resource groups, never the subscription.** The setup
in `SETUP.md` assigns Contributor at resource-group scope only. The convenient-looking
`--scope /subscriptions/<id>` form would hand this pipeline write access to his resources,
and there is no reason for it to have that.

Also: do not let a pipeline run execute during his segment. Check the Actions tab is quiet
before he starts.

## How this is enforced, not just requested

Three mechanisms, each independent of you remembering:

| Guard | Where | What it stops |
|---|---|---|
| `scripts/guard-target.sh` | Runs before every `az` command that writes, and again on the name Bicep reports | A resource group or function app name that is not this project's. Fails in about two seconds with the allowed names printed |
| `scripts/check-isolation.sh` | Runs on every pull request and every deployment | Another project's resource names pasted anywhere into this repository, a non-Canadian region in a parameter file, or a credential-looking string |
| Resource-group-scoped RBAC + per-environment federated credentials | Azure, set up once | Even a deliberate attempt to deploy elsewhere. Dev and Test identities cannot write to Production, and none can write outside their own group |

The first two are in this repository and work offline. Try them:

```bash
bash ./scripts/guard-target.sh rg-nqcicd-dev-cc      # passes
bash ./scripts/guard-target.sh some-other-rg         # fails, exit 1
bash ./scripts/check-isolation.sh                    # passes on a clean checkout
```

## What you do not need

You do not need API Management, Service Bus, Key Vault, a Logic App, or any shared
networking. This segment is one Function App, one storage account, one workspace, per
environment. If you find yourself creating any of those other services, stop and ask why.

## If something does go wrong

Tell the other presenter immediately, before the demo, even if you think you reverted it.
Azure role assignments, policy evaluations and deleted resources are all things he can
check in minutes with the right information and cannot discover at all without it.
