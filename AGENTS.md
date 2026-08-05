# AGENTS.md — Development flow

Salesforce ALM via **Agentia** (Copado). Prefer **Agentia MCP tools** when available. If MCP is unavailable, use `agentia … --json` as fallback — never substitute `sf data `* for Copado work items.

**Before any ALM or metadata command:** read `[.agentia/config.json](.agentia/config.json)` (`defaults` + `context`). Use those IDs; do not re-resolve unless auth or org setup changed.

---

## Config not in `.agentia/config.json`

| Item                    | Value                                   |
| ----------------------- | --------------------------------------- |
| CLI                     | `@copado/agentia-cli@0.26.0-alpha.0`    |
| Copado username         | `nvijay@copado.com`                     |
| Copado Org SF org alias | `AgentforceHeadless-Testbackend`        |
| Base branch             | `main` (see `lastBaseBranch` in config) |
| Development Org alias   | `nvijaydxdevhub_dev`                    |

**Gaps to fill in config when missing:**

- `context.releaseId` — Copado project Releases tab, or `agentia project get <project-id> --json`
- `context.recordType` — project settings, or copy from an existing story via `agentia work get <id> --json`

**Human setup (not the agent):**

```sh
npm install -g @copado/agentia-cli@0.26.0-alpha.0
agentia auth set --cicd <api-key> --region na   # or --custom-url
```

Cursor MCP (start from repo root):

```json
{
  "mcpServers": {
    "agentia": { "command": "agentia", "args": ["mcp", "start"] }
  }
}
```

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

1. **Clean working tree**, then `agentia_work_set` / `agentia work set <id>` → branch `feature/<story-name>`.
2. Implement Salesforce metadata under `force-app/`.
3. **Deploy to source org** — once all changes are ready to commit, deploy to the source org before committing. Dry-run first, then deploy. See [Deploy to source org](#deploy-to-source-org).
4. **Exit gate — dependency check** (once, after source deploy, before commit/push/submit/done or reporting complete): see [Metadata dependencies](#metadata-dependencies).
5. Commit only when the user asks — after deploy and dependency gate pass.
6. `agentia_work_push` / `agentia work push` — only after dependency gate passes.

### 5. Submit, done, monitor

1. Confirm deploy and dependency check already passed (re-run only if deploy or retrieved deps changed).
2. `agentia_work_status` / `agentia work status` — story + related jobs.
3. `agentia work submit` — validation (`validate=true`). **Confirm with user first.**
4. On failure: `agentia job list` → `job get` → `job log get`.
5. `agentia work done` — promote (`validate=false`). **Confirm with user first.**

---

## Global rules

- **Agentia only for ALM** — work items, push, submit, done, promotions. Use `sf` for **source-org deploy** only (required before commit; see [Deploy to source org](#deploy-to-source-org)).
- Pipeline/job commands need `organizationId` + `userId` from config `context`.
- Metadata dependency/compare commands need `pipelineId`, `sourceOrgId`, `sourceCredential` from config, plus `targetOrgId` from the pipeline connection (see [Metadata dependencies](#metadata-dependencies)).
- Git-backed commands (`work set`, `work push`, `work submit`, `work done`) operate on the **current repo**; MCP must start from repo root. `work set` and `work push` require a **clean tracked working tree**.
- After `work set`, omit work-item ID on `work get`, `work update`, `work status` — active item is cached locally.
- **Confirm first:** `work delete`, `work submit`, `work done`, `job kill`, promotion conflict resolve/unresolve.
- Never echo secrets from `auth get`.
- If Auto-review blocks an Agentia command, request approval and retry — do not bypass with `sf data *`.
- CLI fallback: prefer `--json` output; success is `{ status: 0, result }`.

---

## Deploy to source org

**When:** once all implementation changes are ready to commit — after coding, before commit and dependency analysis.

**Target:** Development Org alias from the config table (`nvijaydxdevhub_dev`), which maps to `context.sourceOrgId`.

**How:**

```sh
# Validate first
sf project deploy start --dry-run --source-dir force-app --target-org nvijaydxdevhub_dev --wait 30 --json

# Deploy on success
sf project deploy start --source-dir force-app --target-org nvijaydxdevhub_dev --wait 30 --json
```

Use `--metadata` or a manifest when the change set is narrow. Fix deploy errors before proceeding. Do not commit until the source-org deploy succeeds.

---

## Metadata dependencies

**When:** once after changes are **deployed to the source org** and before work ends (commit/push/submit/done). Not at entry.

**Prerequisite:** [Deploy to source org](#deploy-to-source-org) must succeed first so dependency analysis runs against live org metadata, not just local files.

**Resolve destination org:** from the pipeline connection whose source environment matches the story's source org (`defaults.environment` or `context.sourceOrgId`):

```sh
agentia pipeline connection list --pipeline-id <context.pipelineId> --json
```

Use `destinationEnvironment.orgId` as `targetOrgId` (e.g. dev1 → Staging).

**How** (CLI; MCP lacks `--from-changes` and `--target-org-id`):

```sh
agentia metadata dependency list \
  --from-changes --base-ref origin/main \
  --pipeline-id <context.pipelineId> \
  --source-org-id <context.sourceOrgId> \
  --source-credential-id <context.sourceCredential> \
  --target-org-id <destinationOrgId> \
  --json
```

This compares **source org** (where changes are deployed) against **destination org** (next environment in the pipeline).

**If missing deps:** list them, retrieve into `force-app/` (`agentia metadata content get`), redeploy to source org, then re-run dependency analysis. Include retrieved files in commits when asked. Do not push/submit/done with org-only deps unless the user explicitly accepts documented gaps.

**Common misses:** Apex referenced by LWC/controllers, custom metadata + Default records, named/external credentials, permission sets and labels referenced by UI.

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
- `sf` **CLI** — no `sf project retrieve start`, `sf data `*, or other `sf` commands for story context, dependency discovery, or implementation scaffolding. **Exception:** required [source-org deploy](#deploy-to-source-org) before commit.
- **Copado CLI** — no `copado `* commands for work items, metadata, pipeline actions, or story context.

**Use instead (Agentia MCP or** `agentia … --json`**):**

| Need                              | Agentia command / MCP tool                                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Story specs & acceptance criteria | `agentia_work_get` / `agentia work get <id> --json`                                                                      |
| Create or update a story          | `agentia_work_create`, `agentia_work_update` / `agentia work create`, `agentia work update --json`                       |
| Branch & active story             | `agentia_work_set` / `agentia work set <id> --json`                                                                      |
| Metadata in org / repo            | `agentia_metadata_content_get`, `agentia_metadata_list` / `agentia metadata content get`, `agentia metadata list --json` |
| Deploy to source org              | `sf project deploy start` (dry-run, then deploy) — required before commit                                                |
| Missing dependencies              | `agentia metadata dependency list --from-changes --target-org-id … --json` (after source deploy)                         |
| Pipeline destination org          | `agentia_pipeline_connection_list` / `agentia pipeline connection list --pipeline-id … --json`                           |
| Push, submit, promote             | `agentia_work_push`, `agentia_work_submit`, `agentia_work_done` / matching `agentia work * --json`                       |

Read the story from Agentia, implement from its specs, deploy to source org, run cross-org dependency analysis, retrieve missing metadata via Agentia, and push through Agentia. Use `sf` only for the required source-org deploy (and when the user explicitly asks for other local deploy/retrieve).
