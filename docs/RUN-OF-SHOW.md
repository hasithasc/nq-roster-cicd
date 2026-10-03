# Run of show — 15 minutes

The one-line brief: *demonstrate how college staff promote an integration from Development
through Test/UAT into Production and roll it back if needed, including testing, approvals,
environment-specific configuration, version control and audit history.*

## Before you start: what to pre-stage

A full pipeline run takes two to four minutes per environment, mostly the remote build.
Three live runs would consume most of your 15 minutes watching a spinner.

So: **run everything except the production promotion before the demo begins.**

| Item | State when you walk in |
|---|---|
| The pull request for ROSTER-14 | Open, CI green, reviewer approved, **not merged** |
| Development | Already on the previous version (1.0.x), healthy, tab open on `/api/version` |
| Test/UAT | Already on the previous version, tab open on `/api/version` |
| Production | Already on the previous version, tab open on `/api/version` |
| The roster URL | Tab open on `/api/classes/2271-HCA1010-01/roster` for all environments |
| Actions tab | Quiet. No queued or running workflow |

Browser tabs, left to right, in the order you will need them: the PR, the Actions tab,
dev `/api/version`, prod `/api/version`, prod roster, the Azure resource group.

The one thing you run live is the merge, which triggers the deploy and the approval gate.
While production deploys, you narrate the audit trail — that fills the wait with content
instead of silence.

## 0:00–1:30 — What this answers

One slide: Development → Test/UAT → Production, with approval gates before Test and Production.

> "You've just seen the integration itself. The question I'm answering is the one that
> comes after it's built: how does your team change it safely? I'm going to make a small
> change that the Registrar's office asked for, take it from test into production in front
> of you, discover that it's wrong, and put the previous version back."

Say up front that this runs in its own resource groups, separate from the integration
segment. It takes ten seconds and pre-empts the question.

## 1:30–3:30 — The repository

Walk the folders without reading them out:

- `src/roster_api/` — the Function App. Four endpoints, about a hundred lines
- `tests/` — the unit tests that block a merge
- `infra/main.bicep` — the infrastructure, in source control like the code
- `infra/dev.parameters.json` / `prod.parameters.json` — **the difference between the
  environments, in two small files**
- `.github/workflows/` — the pipeline

Open the two parameter files side by side. This is the environment-configuration evidence:

> "Same code in both. Development returns full learner IDs because developers need to
> debug with them. Production masks them — `DEMO-**01` — because production holds real
> student data and we're an Alberta public body. Nobody edits a setting in the portal to
> make that happen, and nobody can forget to. It's in the repository, it's reviewed, and
> it's applied by the pipeline."

Then `main`'s branch protection: a PR is required, one approval, two checks must pass.

## 3:30–6:30 — The pull request

Open the PR. Show, in this order:

1. The work item it refers to (ROSTER-14)
2. The diff — four lines
3. The checks: lint, unit tests, Bicep validation, isolation check — all green
4. The reviewer's approval, by name

> "Two things had to happen before this could merge: a machine had to agree the tests pass,
> and a person had to agree the change is right. Neither can be skipped — I can't merge
> this myself even though I wrote it."

Merge it.

## 6:30–9:00 — Development and Test/UAT

The push triggers the pipeline. Rather than watching it, show the run you pre-staged
earlier and walk its shape:

> "One build job, then three deploy jobs. The build happens once and produces one package.
> Development, Test and Production use the same SHA-256 — Production gets the identical
> bits that passed in Test/UAT."

Then the evidence: Development `/api/version` shows the new commit and full learner IDs.
Approve Test/UAT, then show the same commit with masked learner IDs and its smoke test.

> "The smoke test you just saw pass isn't checking that the deployment reported success.
> It calls the real URL and asserts the commit it finds is the commit we deployed, and
> that the masking rule for this environment is in force."

## 9:00–11:30 — Promotion to Production

Back to the live run. It is sitting at **Review pending**.

> "This is the gate. The pipeline has done everything it can do on its own, and now it
> stops. It will not deploy to production until a named person approves it, and I'm not on
> that list — deliberately."

Have your approver approve it, visibly, from their own machine if possible.

While it deploys (two to four minutes), use the time:

- Show the deployment history on the production environment: every deployment, who
  approved it, when
- Show the commit trail and the release tag
- Show the Azure Activity Log for the resource group: which identity deployed, and when

> "And note there's no Azure password or publish profile stored in GitHub. The pipeline
> signs in with a short-lived token that Azure only trusts from this repository, for this
> environment. There's no credential to leak or rotate."

When it finishes: prod `/api/version` shows the new commit and `"environment":
"Production"`. The prod roster shows the new field — and masked IDs.

## 11:30–14:00 — It's wrong. Roll back.

Open the production roster and read the number.

> "That says ten. There are eight students enrolled in that class — one dropped, one is
> waitlisted. The pipeline did everything we asked. It ran the tests, it got a human
> approval, it deployed exactly what we tested. The gate is only as good as the test
> behind it."

Then:

> "Here's what the pipeline actually bought us."

**Actions → the last successful run before this one → Re-run all jobs.**

> "There are no deployment slots on this hosting plan, and we don't need them. The
> pipeline knows exactly which commit was live before, so rolling back is redeploying it.
> This is Microsoft's documented recovery path for this plan, not a workaround."

Two things to know so neither surprises you:

- The re-run **also stops at the approval gate**. That is correct and worth saying: the
  control applies to going backwards as well as forwards.
- The re-run restores the original version number, because the run number travels with the
  run. So `/api/version` goes from 1.0.8 back to 1.0.7 — the endpoint tells the truth
  about a rollback, not just a deployment.

Refresh prod `/api/version`: previous commit. Refresh the roster: the count field is gone.

> "Production is back where it was, in about two minutes, with a record of who did it. The
> bad version is still in the history — nothing was deleted. Tomorrow we fix the test,
> which is the actual defect here, and promote again through the same gate."

## 14:00–15:00 — Audit history

One screen, three things, fifteen seconds each:

1. The production environment's deployment history: every promotion and the rollback, each
   with an approver's name and a timestamp
2. The git history: every change, who wrote it, who reviewed it, which commit is in which
   environment
3. The Azure Activity Log: the same events from Azure's side, naming the identity

> "Nothing here is a report somebody compiles. It's a by-product of doing the work this
> way — which is what makes it trustworthy."

## If something goes wrong on stage

| Symptom | Do this |
|---|---|
| A run fails to sign in to Azure (`AADSTS70021`) | Do not debug it live. Switch to the pre-recorded run or the screenshots, and carry on narrating. The cause is almost always a federated credential subject — fix it afterwards |
| The deploy is taking much longer than rehearsed | Keep talking through the audit trail; you have about three minutes of material there. If it passes four minutes, switch to the completed run from your rehearsal |
| The approval does not appear | Check you are looking at the run, not the workflow file. If the reviewer cannot approve, approve it yourself and say plainly that you would not be the approver in a real environment |
| A URL returns 404 | The app is cold or the route is wrong. Hit `/api/health` first, then retry |

Have a screenshot pack of every step in a folder, in order, as the fallback. You will
almost certainly not need it, and you will present better knowing it is there.
