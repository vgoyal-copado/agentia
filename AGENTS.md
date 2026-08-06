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
2. **Existing org metadata** — before creating or editing a file locally, check whether it already exists in the source org (`agentia_metadata_list` / `agentia metadata list --json`). If it does, retrieve it with `agentia_metadata_content_get` / `agentia metadata content get --json` and modify the retrieved copy. Do not recreate from scratch.
3. Implement Salesforce metadata under `force-app/`. Author files directly or retrieve existing org metadata via Agentia — never use `sf template generate` or other `sf` commands to scaffold metadata.
4. **Validate deploy to source org** — once all changes are ready, dry-run against the source org before committing. See [Validate deploy to source org](#validate-deploy-to-source-org).
5. **Stage changes** — after dry-run succeeds, `git add` relevant files under `force-app/`. Do not commit yet.
6. **Exit gate — dependency check** (once, after staging, before commit/push/submit/done or reporting complete): see [Metadata dependencies](#metadata-dependencies).
7. Commit only when the user asks — after validation and dependency gate pass (including any retrieved dependencies).
8. `agentia_work_push` / `agentia work push` — only after dependency gate passes.

### 5. Submit, done, monitor

1. Confirm dry-run validation and dependency check already passed (re-run only if changes or retrieved deps changed).
2. `agentia_work_status` / `agentia work status` — story + related jobs.
3. `agentia work submit` — validation (`validate=true`). **Confirm with user first.**
4. On failure: `agentia job list` → `job get` → `job log get`.
5. `agentia work done` — promote (`validate=false`). **Confirm with user first.**

---

## Global rules

- **Agentia only for ALM** — work items, push, submit, done, promotions. Use `sf` **only** for [source-org deploy validation](#validate-deploy-to-source-org) (`sf project deploy start --dry-run`). No other `sf` commands — including `sf template generate`, `sf project retrieve start`, `sf data *`, or any other `sf` subcommand.
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

**This is the only permitted use of the `sf` CLI.** Do not run any other `sf` command. **Do not run an actual deploy** — dry-run only.

**How:**

```sh
sf project deploy start --dry-run --source-dir force-app --target-org nvijaydxdevhub_dev --wait 30 --json
```

Use `--metadata` or a manifest when the change set is narrow. Fix validation errors before proceeding. After dry-run succeeds, stage changes (`git add`) and run the dependency check — do not commit until the dependency gate passes.

---

## Metadata dependencies

**When:** once after changes are **validated** (dry-run) and **staged** (`git add`), and before commit/push/submit/done. Not at entry.

**Prerequisites:** [Validate deploy to source org](#validate-deploy-to-source-org) must succeed first. Stage changes after validation and before running this check — do not commit first.

**Why not `--from-changes` before commit?** Agentia's `--from-changes` runs `git diff --name-only <base-ref>...HEAD`, which only sees **committed** branch changes. Staged, unstaged, and untracked files are ignored. Use the helper below instead.

**Resolve destination org:** from the pipeline connection whose source environment matches the story's source org (`defaults.environment` or `context.sourceOrgId`):

```sh
agentia pipeline connection list --pipeline-id <context.pipelineId> --json
```

Use `destinationEnvironment.orgId` as `targetOrgId` (e.g. dev1 → Staging). The helper script resolves this automatically from `.agentia/config.json`.

**How** (pre-commit; staged + unstaged + untracked vs base branch):

```sh
node scripts/agentia/dependency-check.mjs --json
```

The script:

1. Reads `pipelineId`, `sourceOrgId`, and `sourceCredential` from `.agentia/config.json`.
2. Collects local changes against `origin/<lastBaseBranch>` (override with `--base-ref`).
3. Maps changed paths under `force-app/` to metadata selections (Apex, LWC, FlexiPage, etc.).
4. Builds a `--stdin` request and calls `agentia metadata dependency list`.

Use `--dry-run` to inspect the generated JSON without calling Agentia. Pass `--target-org-id <id>` to override auto-resolution.

**After commit** (optional; same selections, committed-only diff):

```sh
agentia metadata dependency list \
  --from-changes --base-ref origin/main \
  --pipeline-id <context.pipelineId> \
  --source-org-id <context.sourceOrgId> \
  --source-credential-id <context.sourceCredential> \
  --target-org-id <destinationOrgId> \
  --json
```

This compares **source org** against **destination org** (next environment in the pipeline).

**If missing deps:**

1. List every missing dependency reported.
2. Retrieve each into `force-app/` via `agentia_metadata_content_get` / `agentia metadata content get --json` (source org).
3. Re-run dry-run validation if retrieved files affect deployability.
4. Stage all retrieved files (`git add`) alongside story changes.
5. Re-run dependency analysis until no retrievable gaps remain.

**Always include retrieved dependency files in the commit** — they are part of the story change set, not optional add-ons. Do not push/submit/done with org-only deps unless the user explicitly accepts documented gaps.

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
- `sf` **CLI** — no `sf` commands except `sf project deploy start --dry-run` for [source-org deploy validation](#validate-deploy-to-source-org). Never use `sf template generate`, `sf project retrieve start`, `sf data *`, or any other `sf` subcommand.
- **Copado CLI** — no `copado `* commands for work items, metadata, pipeline actions, or story context.

**Use instead (Agentia MCP or** `agentia … --json`**):**

| Need                              | Agentia command / MCP tool                                                                                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Story specs & acceptance criteria | `agentia_work_get` / `agentia work get <id> --json`                                                                                                                      |
| Create or update a story          | `agentia_work_create`, `agentia_work_update` / `agentia work create`, `agentia work update --json`                                                                       |
| Branch & active story             | `agentia_work_set` / `agentia work set <id> --json`                                                                                                                      |
| Metadata in org / repo            | `agentia_metadata_content_get`, `agentia_metadata_list` / `agentia metadata content get`, `agentia metadata list --json`                                                 |
| Validate deploy to source org     | `sf project deploy start --dry-run` — required before staging and commit; no actual deploy                                                                               |
| Missing dependencies              | `node scripts/agentia/dependency-check.mjs --json` (pre-commit, after validation and staging); retrieve via `agentia_metadata_content_get`, stage, and include in commit |
| Pipeline destination org          | `agentia_pipeline_connection_list` / `agentia pipeline connection list --pipeline-id … --json`                                                                           |
| Push, submit, promote             | `agentia_work_push`, `agentia_work_submit`, `agentia_work_done` / matching `agentia work * --json`                                                                       |

Read the story from Agentia, implement from its specs, dry-run validate against source org, stage changes, run cross-org dependency analysis with `node scripts/agentia/dependency-check.mjs --json` (before commit), retrieve missing metadata via Agentia and include it in the commit, and push through Agentia. Use `sf project deploy start --dry-run` only — no other `sf` commands, and never run an actual deploy.
