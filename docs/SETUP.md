# One-time setup

Allow about 90 minutes the first time, then rehearse twice. Do this at least three days
before the demo, not the night before: two of the steps below depend on someone else
(a GitHub plan check and a second person to act as approver).

Read `ISOLATION-RULES.md` first.

## Step 0 — Decide the repository visibility. Do this before anything else.

The approval gate is the centrepiece of this segment, and **on GitHub Free, Pro and Team,
required reviewers and wait timers only work on public repositories.** Private
repositories need GitHub Enterprise. If you build everything on a private repo and
discover this on demo day, the gate simply will not be there to configure.

Two acceptable answers:

- **Public repository** (recommended). Everything here is synthetic — invented learners,
  no secrets, no credentials, authentication by OIDC rather than a stored key. A public
  repo makes the gate available on any plan, including Free.
- **Private repository on GitHub Enterprise.** Confirm the plan in
  *Organization settings → Billing* before you rely on it.

Do not plan to "show the setting" on a private repo. It will not be in the menu.

## Step 1 — Create the three resource groups

```bash
SUB="<the subscription the demo runs on - ask the other presenter>"
az account set --subscription "$SUB"

for ENV in dev test prod; do
  az group create -n "rg-nqcicd-${ENV}-cc" -l canadacentral --tags costCenter=IT-Integration-Demo
done
```

## Step 2 — Check the Flex Consumption quota in Canada Central

The quota is per subscription per region and is shared with the other demo segment.
Standard subscriptions get 250 cores; Azure Free Trial and Azure for Students get 15.
This project uses 512 MB instances (0.25 cores each) with capped scale in all three
environments, so check that sufficient regional headroom exists before you build.

Portal: open any Flex Consumption app in the subscription → **Diagnose and solve
problems** → search *Flex Consumption Quota* → choose Canada Central.

## Step 3 — Create one managed identity per environment

A user-assigned managed identity rather than an Entra app registration: it needs no
directory-level permissions, and `azure/login` treats it identically.

One identity per environment is deliberate. The Development or Test identity physically
cannot deploy to Production, which is stronger separation than any workflow condition.

```bash
for ENV in dev test prod; do
  az identity create -g rg-nqcicd-$ENV-cc -n id-roster-deploy-$ENV -l canadacentral
done
```

Collect the values GitHub will need:

```bash
az identity show -g rg-nqcicd-dev-cc  -n id-roster-deploy-dev  --query "{clientId:clientId, principalId:principalId}" -o json
az identity show -g rg-nqcicd-test-cc -n id-roster-deploy-test --query "{clientId:clientId, principalId:principalId}" -o json
az identity show -g rg-nqcicd-prod-cc -n id-roster-deploy-prod --query "{clientId:clientId, principalId:principalId}" -o json
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o json
```

## Step 4 — Federated credentials: match the ENVIRONMENT, not the branch

This is the step that most often fails, and the error it produces (`AADSTS70021`, no
matching federated identity record) does not explain itself.

The moment a job declares `environment: production`, the OIDC token's subject becomes
`repo:OWNER/REPO:environment:production` — **not** `ref:refs/heads/main`. Both deploy jobs
in `deploy.yml` use environments, so every credential must use the environment form.

```bash
REPO="OWNER/REPO"      # e.g. acme-college/nq-roster-cicd

az identity federated-credential create \
  --identity-name id-roster-deploy-dev --resource-group rg-nqcicd-dev-cc \
  --name gh-development \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:${REPO}:environment:development" \
  --audiences api://AzureADTokenExchange

az identity federated-credential create \
  --identity-name id-roster-deploy-test --resource-group rg-nqcicd-test-cc \
  --name gh-test \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:${REPO}:environment:test" \
  --audiences api://AzureADTokenExchange

az identity federated-credential create \
  --identity-name id-roster-deploy-prod --resource-group rg-nqcicd-prod-cc \
  --name gh-production \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:${REPO}:environment:production" \
  --audiences api://AzureADTokenExchange
```

The GitHub Environment names (`development`, `test`, `production`) must match these strings
exactly, including case.

## Step 5 — Role assignments, at RESOURCE GROUP scope only

```bash
for ENV in dev test prod; do
  PRINCIPAL=$(az identity show -g rg-nqcicd-$ENV-cc -n id-roster-deploy-$ENV --query principalId -o tsv)
  RG_ID=$(az group show -n rg-nqcicd-$ENV-cc --query id -o tsv)

  # Deploy the Bicep (create resources, assign roles on its own storage account)
  az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
    --role "Contributor" --scope "$RG_ID"
  az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
    --role "User Access Administrator" --scope "$RG_ID"

  # Publish the application package
  az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
    --role "Website Contributor" --scope "$RG_ID"
done
```

`--scope "$RG_ID"` is the whole point. Never substitute `/subscriptions/<id>`.

*Why User Access Administrator:* the template grants the identity storage data roles on the
storage account it creates, and creating a role assignment requires that permission. If
your organisation will not allow it, run the Bicep once yourself and remove the three
`roleAssignments` resources plus the matching `dependsOn` entries from `main.bicep`.

## Step 6 — GitHub Environments

*Settings → Environments → New environment.* Create **development**, **test** and **production**,
named exactly like that.

On **test** and **production**:

- **Required reviewers** → add a person who is *not you*. The separation-of-duties point
  only lands if the panel sees a different name approve it.
- Tick **Prevent self-review**.
- Leave the wait timer off; you do not have 10 minutes to spare on stage.

On each environment, add:

| Kind | Name | development | test | production |
|---|---|---|---|---|
| Variable | `AZURE_RESOURCE_GROUP` | `rg-nqcicd-dev-cc` | `rg-nqcicd-test-cc` | `rg-nqcicd-prod-cc` |
| Secret | `AZURE_CLIENT_ID` | dev identity clientId | test identity clientId | prod identity clientId |
| Secret | `AZURE_TENANT_ID` | tenant ID | tenant ID | tenant ID |
| Secret | `AZURE_SUBSCRIPTION_ID` | subscription ID | subscription ID | subscription ID |

None of these is a credential in the usual sense — they are identifiers. The actual trust
is the federated credential from Step 4. Worth saying out loud during the demo.

## Step 7 — Branch protection on main

*Settings → Branches → Add rule* for `main`:

- Require a pull request before merging, with 1 approval
- Require status checks to pass: **Lint and unit tests**, **Validate infrastructure and isolation**
- Do not allow bypassing

Edit `.github/CODEOWNERS` and replace the placeholder with the reviewer's GitHub username.

## Step 7a — A Windows-specific detail about the shell scripts

Git on Windows does not record the execute bit, so `scripts/*.sh` will arrive in the
repository non-executable. The workflows invoke them as `bash ./scripts/x.sh` for exactly
this reason, so nothing breaks. If you ever change that to `./scripts/x.sh`, also run:

```bash
git update-index --chmod=+x scripts/guard-target.sh scripts/check-isolation.sh scripts/smoke-test.sh
```

otherwise the job fails with `Permission denied`.

## Step 8 — First deployment

Push to `main`. The run builds once, deploys to Development, pauses for the Test/UAT
approval, and then pauses again for Production approval. Confirm all three environments:

```
https://func-roster-nqcicd-dev-<suffix>.azurewebsites.net/api/version
https://func-roster-nqcicd-test-<suffix>.azurewebsites.net/api/version
https://func-roster-nqcicd-prod-<suffix>.azurewebsites.net/api/version
```

Development should report `"environment": "Development"` and unmasked learner IDs;
Test/UAT and Production should use masked IDs such as `DEMO-**01`. That difference is
the environment-specific-configuration evidence, and it comes from one build.

Save all three URLs. You will open them repeatedly on stage — put them in browser tabs, not in
your memory.

## Step 9 — Rehearse twice, and time it

Measure the real duration of a full run, including the remote build. Flex Consumption
installs the Python dependencies on the server during deployment, so a run is typically
two to four minutes per environment. Write the number down; it decides how much of the
demo you pre-stage. See `RUN-OF-SHOW.md`.
