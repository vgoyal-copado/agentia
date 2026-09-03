# AGENTS.md — Development flow

Salesforce ALM via **Agentia** (Copado). Prefer **Agentia MCP tools** when available. If MCP is unavailable, use `agentia … --json` as fallback — never substitute `sf data` * for Copado work items.

**Before any ALM or metadata command:** read `[.agentia/config.json](.agentia/config.json)` (`defaults` + `context`). Use those IDs; do not re-resolve unless auth or org setup changed.

---

## Config not in `.agentia/config.json`


| Item                    | Value                                   |
| ----------------------- | --------------------------------------- |
| CLI                     | `@copado/agentia-cli@0.92.0-alpha.0`    |
| Copado username         |                                         |
| Copado Org SF org alias |                                         |
| Base branch             | `main` (see `lastBaseBranch` in config) |
| Development Org alias   | `dev-vg`                                |


**Gaps to fill in config when missing:**

- `context.releaseId` — Copado project Releases tab, or `agentia project get <project-id> --json`
- `context.recordType` — project settings, or copy from an existing story via `agentia work get <id> --json`

---



## Development flow



### 1. Orient

1. Read `.agentia/config.json`.
2. Confirm project defaults align (`agentia project default get --json`).
3. Resolve empty `releaseId` / `recordType` in config if needed.



### 2. Create a user story

1. Use `agentia_work_create` (MCP) or `agentia work create --json` (CLI).
2. Merge `defaults` + `context` from config. Always pass `sourceCredential`; pass `releaseId` when set.
3. Never create Copado stories with `sf data create record`.
4. If scope spans many metadata layers, create a parent/epic and propose child breakdown (see [Large stories](#large-stories)).



### 3. Understand a user story

1. `agentia_work_get` / `agentia work get <id>` — read specs, acceptance criteria, env/pipeline context.
2. Assess size before coding ([Large stories](#large-stories)).
3. If the user asked to **implement**, continue to step 4.



### 4. Implement

1. For all the implementations you do, use agentia cli and not agentia mcp
2. **Existing org metadata (mandatory before any local edit)** — if metadata exists in the source org, treat the **org** as source of truth, not the repo copy.
  - Check org presence (`agentia_metadata_list` / `agentia metadata list --json`).
  - Retrieve with `agentia_metadata_content_get` / `agentia metadata content get --json`, write under `force-app/`, then apply story changes on that retrieved copy.
  - **Never** edit a repo file blindly when the same component exists in the org — org-only changes (e.g. Lightning App Builder field additions) are lost on deploy.
  - **FlexiPage / Lightning page layouts:** always retrieve + compare first. These are commonly edited in the org UI and drift from git.
3. Implement Salesforce metadata under `force-app/`. Author files directly or retrieve existing org metadata via Agentia — never use `sf template generate` or other `sf` commands to scaffold metadata.
4. **Validate deploy to source org** — once all changes are ready, dry-run against the source org before committing. See [Validate deploy to source org](#validate-deploy-to-source-org).
5. **Stage changes** — after dry-run succeeds, `git add` relevant files under `force-app/`. Do not commit yet.
6. Commit the changes using agentia cicd work commit command



### 5. Submit, done, monitor

1. Confirm dry-run validation, pre- and post-deploy dependency resolve, and source-org deploy already passed (re-run only if changes or retrieved deps changed).d
2. `agentia_work_status` / `agentia work status` — story + related jobs.
3. `agentia work submit` — validation (`validate=true`). **Confirm with user first.**
4. On failure: `agentia job list` → `job get` → `job log get`.
5. `agentia work done` — promote (`validate=false`). **Confirm with user first.**

---



## Global rules

- **Agentia only for ALM** — work items, push, submit, done, promotions. Use `sf` **only** for [source-org deploy validation](#validate-deploy-to-source-org) (`sf project deploy start --dry-run`) and [source-org deploy](#deploy-to-source-org) (`sf project deploy start`). No other `sf` commands — including `sf template generate`, `sf project retrieve start`, `sf data` *, or any other `sf` subcommand.
- **Prefer org source of truth** — if metadata already exists in the source org, retrieve it via Agentia and edit that file; do not author a new local copy from scratch.
- Pipeline/job commands need `organizationId` + `userId` from config `context`.
- Metadata dependency/compare commands need `pipelineId`, `sourceOrgId`, `sourceCredential` from config, plus `targetOrgId` from the pipeline connection (see [Metadata dependencies](#metadata-dependencies)).
- Git-backed commands (`work set`, `work push`, `work submit`, `work done`) operate on the **current repo**; MCP must start from repo root. `work set` and `work push` require a **clean tracked working tree**.
- After `work set`, omit work-item ID on `work get`, `work update`, `work status` — active item is cached locally.
- **Confirm first:** `work delete`, `work submit`, `work done`, `job kill`, promotion conflict resolve/unresolve.
- Never echo secrets from `auth get`.
- If Auto-review blocks an Agentia command, request approval and retry — do not bypass with `sf data *`.
- CLI fallback: prefer `--json` output; success is `{ status: 0, result }`.

---



## Validate deploy to source org

**When:** once all implementation changes are ready — after coding, before staging, commit, and dependency analysis.

**Target:** Development Org alias from the config table (`nvijaydxdevhub_dev`), which maps to `context.sourceOrgId`.

**This is a permitted use of the** `sf` **CLI** (see also [Deploy to source org](#deploy-to-source-org)). **Dry-run only** — do not run an actual deploy in this step.

**How:**

```sh
sf project deploy start --dry-run --source-dir force-app --target-org nvijaydxdevhub_dev --wait 30 --json
```

Prefer `--metadata` or a manifest when the change set is narrow — **do not** deploy all of `force-app/` if the story only touches a few components. A broad deploy overwrites org-only layout changes on files that were not retrieved first. Fix validation errors before proceeding. After dry-run succeeds, stage changes (`git add`) and run pre-deploy [Metadata dependencies](#metadata-dependencies) — do not commit until both dependency passes and source-org deploy are complete.

---



## Deploy to source org

**When:** after pre-deploy [Metadata dependencies](#metadata-dependencies) gate passes and the final dry-run validation succeeds — **before** the mandatory post-deploy dependency pass.

**Target:** Development Org alias from the config table (`nvijaydxdevhub_dev`), which maps to `context.sourceOrgId`.

**Prerequisite:** dry-run validation and pre-deploy dependency resolve must both pass first. If dependency retrieve added new files, re-run dry-run and pre-deploy dependency resolve before deploying.

**How:**

```sh
sf project deploy start --source-dir force-app --target-org nvijaydxdevhub_dev --wait 30 --json
```

Prefer `--metadata` or a manifest when the change set is narrow — same rule as dry-run: avoid full `--source-dir force-app` unless the story intentionally changes the whole tree. Fix deploy errors before proceeding.

**After deploy:** immediately run the mandatory [post-deploy dependency resolve](#post-deploy-dependency-resolve-mandatory) pass. Do not commit or push until that pass completes.

---



## Metadata dependencies

**Source of truth:** `agentia metadata dependency list` only. Do **not** infer dependencies from file contents or use helper scripts.

**When:** run **twice** during implementation — a pre-deploy pass and a mandatory post-deploy pass (see below). Both are required before commit/push/submit/done.

**Prerequisites:** [Validate deploy to source org](#validate-deploy-to-source-org) must succeed first. Stage changes after validation — do not commit first.

### Why two passes?

Agentia resolves some dependencies only after the component exists in the source org (common for **Apex → CustomField**, Apex class cross-refs, and LWC → Apex). A pre-deploy pass alone often reports an empty `d` array for new Apex classes and misses fields the code references. **Always re-run dependency list after source-org deploy** — that is when MISSING items like `Case.Needs_Escalation__c` appear and must be retrieved locally so destination-org promotion does not fail.

**Resolve destination org:** from the pipeline connection whose source environment matches the story's source org:

```sh
agentia pipeline connection list --pipeline-id <context.pipelineId> --json
```

Use `destinationEnvironment.orgId` as `targetOrgId` (e.g. dev1 → Staging).

### Mandatory gate

1. **Build metadata selections** from staged, unstaged, and untracked `force-app/` changes (vs `origin/<lastBaseBranch>`). Map each changed file to `{ name, type }` — e.g. `force-app/.../classes/MyClass.cls` → `ApexClass:MyClass`, `force-app/.../lwc/myCmp/` → `LightningComponentBundle:myCmp`.
2. **List dependencies** via Agentia MCP (`agentia_metadata_dependency_list`) or CLI:

```sh
agentia metadata dependency list --stdin --json
```

Stdin body (use IDs from `.agentia/config.json`):

```json
{
  "platformExperience": "sfdx",
  "pipelineId": "<context.pipelineId>",
  "compareOptions": {
    "sourceOrgId": "<context.sourceOrgId>",
    "sourceCredentialId": "<context.sourceCredential>",
    "targetOrgId": "<destinationOrgId>",
    "retrieveMode": "diff_only"
  },
  "metadataSelections": [{ "name": "MyClass", "type": "ApexClass" }]
}
```

For a single component, you can pass flags instead of stdin:

```sh
agentia metadata dependency list \
  --metadata-name MyClass \
  --metadata-type ApexClass \
  --pipeline-id <context.pipelineId> \
  --source-org-id <context.sourceOrgId> \
  --source-credential-id <context.sourceCredential> \
  --target-org-id <destinationOrgId> \
  --retrieve-mode diff_only \
  --json
```

1. **Retrieve MISSING dependencies from the source org.** In the response, each dependency under `d` with `"s": "MISSING"` must be present locally before commit. If the metadata already exists in the source org but not in the repo, retrieve it with Agentia — never use `sf project retrieve start`:

```sh
agentia metadata content get \
  --metadata-type <type> \
  --api-name <name> \
  --pipeline-id <context.pipelineId> \
  --source ENVIRONMENT \
  --source-org-id <context.sourceOrgId> \
  --source-credential-id <context.sourceCredential> \
  --json
```

Write decoded content under `force-app/` (MCP: `agentia_metadata_content_get`). Stage retrieved files (`git add`).

1. **Expand and repeat** — add retrieved components to `metadataSelections`, re-run dependency list, retrieve any new MISSING items, until no retrievable gaps remain.
2. **Re-validate and deploy** — after the pre-deploy gate passes, re-run dry-run if any files were retrieved, then run [Deploy to source org](#deploy-to-source-org).



### Post-deploy dependency resolve (mandatory)

**When:** immediately after [Deploy to source org](#deploy-to-source-org) succeeds — before commit, push, submit, or done.

**Why:** the deploy puts new Apex/LWC into the org index; Agentia can then detect references that were invisible pre-deploy (e.g. custom fields in SOQL/DML, Apex class deps).

**Steps:** repeat the [Mandatory gate](#mandatory-gate) procedure (steps 1–4) using the **full** staged change set (story components + anything retrieved in the pre-deploy pass). For each dependency under `d` with `"s": "MISSING"`:

1. Retrieve from the source org via `agentia metadata content get` / `agentia_metadata_content_get`.
2. Write decoded content under `force-app/`, stage (`git add`).
3. Add retrieved components to `metadataSelections`, re-run dependency list, repeat until only [ignored false positives](#ignored-false-positives) remain.

**Exit criteria:** no retrievable MISSING dependencies left; all retrieved files staged locally and ready to commit with the story. Re-run dry-run if post-deploy retrieve added new files. Destination-org promotion must not fail for metadata the story references — if it is in the org and referenced, it must be in the repo.

**After commit** (optional inspect):

```sh
agentia metadata dependency list \
  --from-changes --base-ref origin/main \
  --pipeline-id <context.pipelineId> \
  --source-org-id <context.sourceOrgId> \
  --source-credential-id <context.sourceCredential> \
  --target-org-id <destinationOrgId> \
  --json
```

Note: `--from-changes` only sees **committed** branch changes. Before commit, build selections from local git diff as in step 1.

### Ignored false positives

Do not retrieve or block on Agentia noise:

- Platform FlexiPage components (`flexipage:tabset`, `flexipage:column`, …)
- Standard-object `CustomObject` parents (`Case`, `Account`, …) when deploying custom **fields**



### Manual fallback

When Agentia reports a missing dependency that is not auto-writable to the expected local path, retrieve via `agentia metadata content get`, place the file under `force-app/`, stage, re-validate, re-run dependency list, then deploy to source org.

**Always include retrieved dependency files in the commit** — they are part of the story change set.

---



## Large stories

Treat as epic (stop and propose breakdown before coding) when **any** apply:


| Signal              | Threshold                                                            |
| ------------------- | -------------------------------------------------------------------- |
| Metadata breadth    | ≥ 4 distinct types                                                   |
| Planned points      | ≥ 13                                                                 |
| Acceptance criteria | ≥ 6 testable scenarios                                               |
| Scope               | Multiple independent deliverables or strict cross-layer deploy order |


When epic-sized: explain why, propose 3–8 ordered child stories (foundation first), ask whether to create children in Copado or implement one slice. Implement only after the user picks a scoped child (or explicitly overrides).

Each child: 1–2 metadata layers, 2–4 acceptance criteria, 3–8 points, clear deploy boundary.

---



## Active work item

Config tracks the last story: `lastWorkItemId`, `lastWorkItem`, `lastBaseBranch`. Prefer these when continuing work in the same repo session.

---



## Build stories with Agentia only

When creating, understanding, or implementing a user story, use **Agentia MCP tools** or `agentia … --json` as the sole ALM and metadata source. Do **not** use git commit history, `sf` CLI, or Copado CLI to build a story.

**Do not use to build a story:**

- **Git commit history** — no `git log`, `git show`, `git checkout <commit/branch> --`, or copying metadata from prior branches/commits to infer scope or reuse implementation.
- `sf` **CLI** — no `sf` commands except `sf project deploy start --dry-run` for [source-org deploy validation](#validate-deploy-to-source-org) and `sf project deploy start` for [source-org deploy](#deploy-to-source-org). Never use `sf template generate`, `sf project retrieve start`, `sf data` *, or any other `sf` subcommand.
- **Copado CLI** — no `copado` * commands for work items, metadata, pipeline actions, or story context.

**Use instead (Agentia MCP or** `agentia … --json`**):**


| Need                                      | Agentia command / MCP tool                                                                                                                                                                                                     |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Story specs & acceptance criteria         | `agentia_work_get` / `agentia work get <id> --json`                                                                                                                                                                            |
| Create or update a story                  | `agentia_work_create`, `agentia_work_update` / `agentia work create`, `agentia work update --json`                                                                                                                             |
| Branch & active story                     | `agentia_work_set` / `agentia work set <id> --json`                                                                                                                                                                            |
| Metadata in org / repo                    | `agentia_metadata_content_get`, `agentia_metadata_list` / `agentia metadata content get`, `agentia metadata list --json`                                                                                                       |
| Validate deploy to source org             | `sf project deploy start --dry-run` — required before staging and dependency resolve                                                                                                                                           |
| Deploy to source org                      | `sf project deploy start` — required after dependency resolve and final dry-run validation                                                                                                                                     |
| Missing dependencies (pre- + post-deploy) | `agentia_metadata_dependency_list` / `agentia metadata dependency list` — run after staging **and again after source-org deploy**; retrieve MISSING items with `agentia_metadata_content_get` / `agentia metadata content get` |
| Pipeline destination org                  | `agentia_pipeline_connection_list` / `agentia pipeline connection list --pipeline-id … --json`                                                                                                                                 |
| Push, submit, promote                     | `agentia_work_push`, `agentia_work_submit`, `agentia_work_done` / matching `agentia work * --json`                                                                                                                             |


Read the story from Agentia, implement from its specs, dry-run validate against source org, stage changes, run pre-deploy dependency resolve via Agentia (`metadata dependency list` → retrieve MISSING items with `metadata content get`), re-validate if deps were retrieved, deploy to source org, run **mandatory post-deploy dependency resolve** (same list → retrieve → stage loop until only false positives remain), re-validate if post-deploy retrieve added files, then push through Agentia. Use `sf project deploy start --dry-run` and `sf project deploy start` only — no other `sf` commands.