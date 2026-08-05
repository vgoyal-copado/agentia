# AGENTS.md — Agentia CLI (`agentia`)

Headless CICD CLI for Salesforce ALM / DevOps agent workflows.

**Target CLI:** `@copado/agentia-cli@0.26.0-alpha.0` (`agentia --version`).

Prefer **MCP tools** (`agentia mcp start`) when available; otherwise shell with **`--json`**.

Always invoke commands as `agentia …` (on PATH).

---

## Project configuration

**Fill in and keep current** — agents read this section and [`.agentia/config.json`](.agentia/config.json) before creating user stories, running metadata commands, or pipeline jobs. Use cached IDs below; do not re-resolve via `sf org display` unless auth or org setup changes.

### Work-item and pipeline inputs

| Field                    | ID / value                  | CLI / MCP flag                         | Notes                                                                      |
| ------------------------ | --------------------------- | -------------------------------------- | -------------------------------------------------------------------------- |
| Organization ID          | `00DdN000011i71VUAQ`        | `--organization-id` / `organizationId` | Required for pipeline & job commands                                       |
| User ID                  | `005dN00000DA8PpQAL`        | `--user-id` / `userId`                 | Required for pipeline & job commands                                       |
| Username                 | `nvijay+aug2026@copado.com` | —                                      | Authenticated Copado user                                                  |
| SF org alias             | `AgentforceHeadless`        | —                                      | Local Salesforce CLI alias                                                 |
| Project ID               | `a15hm000000OFE1AAO`        | `--project`                            | Agentia Pipeline                                                           |
| Source environment ID    | `a0chm000000CesvAAC`        | `--source-environment`                 | Default dev sandbox (`dev1`)                                               |
| **Source credential ID** | `a11hm000000lAK5AAM`        | `--source-credential`                  | Default credential for `dev1`; used on `work create` and metadata commands |
| **Release ID**           | `_FILL_ME_`                 | `--release-id`                         | Target release for new user stories                                        |
| Pipeline ID              | `a0Whm000000AtJNEA0`        | `--pipeline-id`                        | Metadata deps/compare, promotions, jobs                                    |
| Source org ID            | `00DOv00000HQc6HMAT`        | `--source-org-id`                      | Org tied to default source credential                                      |
| Record type ID           | `_FILL_ME_`                 | `--record-type`                        | Omit if project default applies                                            |
| Team ID                  | `a1hhm0000006v3dAAA`        | `--team`                               | Also set via `project default set`                                         |
| Sprint ID                | `a1Yhm0000005DhNEAU`        | `--sprint-id`                          | Also set via `project default set`                                         |
| Epic ID                  | `a0ehm000000kcv7AAA`        | `--epic`                               | Optional parent epic                                                       |
| Feature ID               | `a01hm0000052NLpAAM`        | `--feature`                            | Optional parent feature                                                    |
| Assign to me             | `true`                      | `--assign-me`                          | Sets assignee to current user                                              |

Bold rows (**Source credential ID**, **Release ID**) are the most common gaps — update them when onboarding a new repo or pipeline.

### Persisting configuration

Store IDs in **`.agentia/config.json`** so agents and the CLI share the same values:

```json
{
  "defaults": {
    "project": "a15hm000000OFE1AAO",
    "environment": "a0chm000000CesvAAC",
    "team": "a1hhm0000006v3dAAA",
    "sprint": "a1Yhm0000005DhNEAU",
    "epic": "a0ehm000000kcv7AAA",
    "feature": "a01hm0000052NLpAAM",
    "assignMe": true
  },
  "context": {
    "organizationId": "00DdN000011i71VUAQ",
    "userId": "005dN00000DA8PpQAL",
    "pipelineId": "a0Whm000000AtJNEA0",
    "sourceCredential": "a11hm000000lAK5AAM",
    "sourceOrgId": "00DOv00000HQc6HMAT",
    "releaseId": "",
    "recordType": ""
  }
}
```

- **`defaults`** — synced with `agentia project default set` (project, environment, team, sprint, epic, feature, assignMe).
- **`context`** — repo-local IDs not covered by project defaults: credential, release, pipeline, org, record type.

When creating a user story, merge **project defaults** (`agentia project default get --json`) with **`context`** from config. Always pass `--source-credential` and `--release-id` from `context` when set; omit `--release-id` only if the project does not use releases.

### Resolving missing IDs

| Need                          | Command                                                                                                   |
| ----------------------------- | --------------------------------------------------------------------------------------------------------- |
| Credential for an environment | `agentia environment get <environment-id> --json` → `credentials[].id` (prefer `defaultCredential: true`) |
| Pipeline ID                   | `agentia pipeline list --user-id 005dN00000DA8PpQAL --organization-id 00DdN000011i71VUAQ --json`          |
| Source org ID                 | From `environment get` → `orgId`, or credential → `orgId`                                                 |
| Release ID                    | Copado project Releases tab, or `agentia project get <project-id> --json`                                 |
| Record type ID                | Copado project settings, or copy from an existing story via `agentia work get <id> --json`                |

After resolving, update both this table and `.agentia/config.json`.

---

## Setup (human / CI — not the agent)

```sh

npm install -g @copado/agentia-cli@0.26.0-alpha.0

agentia auth set --cicd <api-key> --region na|emea|emea2|apac|apac2

# or

agentia auth set --cicd <api-key> --custom-url https://test.api.copado.com

# optional CRT

agentia auth set --cicd <api-key> --region na --crt <pat>

```

Cursor MCP:

```json
{
  "mcpServers": {
    "agentia": {
      "command": "agentia",

      "args": ["mcp", "start"]
    }
  }
}
```

Project defaults for `work create` (project, environment, team, sprint) — see [Project configuration](#project-configuration) for IDs and [`.agentia/config.json`](.agentia/config.json) for persistence:

```sh

agentia project default set --project <id> --environment <id> --team <id> --sprint <id> --assign-me

agentia project default get --json

```

Pipeline / job commands use org and user IDs from [Project configuration](#project-configuration). MCP: pass the same values as `organizationId` and `userId`.

---

## Global rules

- Almost all commands support `--json` → `{ status, result }` (or `{ error }`). Prefer JSON; do not parse tables/spinners.

- Pipeline / job commands need `--user-id` and `--organization-id` (MCP: `userId`, `organizationId`). **Use the cached values in [Project configuration](#project-configuration).**

- Metadata inspect/compare/deps typically need `--pipeline-id`, `--source-org-id`, `--source-credential-id` (+ target/branch as needed).

- Never print secrets from `auth get` / `agentia_auth_get`. Do not expose keychain material.

- Confirm before destructive or pipeline-triggering ops: `job kill`, `work delete`, `work submit`, `work done`, conflict resolve/unresolve.

- **Git-backed work commands** (`work set`, `work push`, `work submit`, `work done`) operate on the **current Git repository** (CLI cwd or MCP server process cwd). They require a **clean tracked working tree** for `work set` and `work push`; `work submit` / `work done` push unpushed commits when the branch is ahead of `origin`. Start the MCP server from the intended repo root.

- **Active work item:** after `work set`, `work get`, `work update`, and `work status` accept an omitted ID and default to the last work item set locally.

- **Large user stories:** before implementing any work item, assess size per [Large / epic user stories](#10-large--epic-user-stories). If it qualifies as an epic, **inform the user and propose a breakdown** — do not implement the full scope in one pass unless the user explicitly overrides.

- **Metadata dependencies:** whenever the user asks you to **work on**, **implement**, **build**, or **start** a user story / work item / ticket, run the full dependency lifecycle in [Mandatory: Metadata dependency check](#mandatory-metadata-dependency-check) — check at entry, before every metadata commit, and **again before work ends** (retrieve and add anything still missing).

### Mandatory: Metadata dependency check

**Always check metadata dependencies** when working on Salesforce metadata — not only at promotion time.

**Entry trigger:** any request to work on a user story, work item, or ticket (by ID, name, or “implement this story”) starts the dependency workflow — even if the user does not mention dependencies explicitly.

| When | Required action |

| --- | --- |

| **When asked to work on a story** (after `work get` / `work set`, before writing code) | Read specs and list metadata the story references or will call. Run dependency analysis (single-component and/or change-set as appropriate). Ensure prerequisites are in the repo or will be retrieved in the same change set **before** implementation begins. |

| **Before every git commit** (metadata changes) | Re-run dependency analysis on the full staged change set. **Do not commit** until missing dependencies are retrieved/included or the user explicitly accepts the gap. |

| **Before work ends** (mandatory exit gate — before `work push`, `work submit`, `work done`, or reporting implementation complete) | Re-run `--from-changes` on the **full branch change set** vs `origin/main`. **Retrieve and add** every missing dependency to the repo. Re-run until the change set is dependency-complete or the user explicitly accepts documented gaps. **Do not finish work** with org-only dependencies still missing from the branch. |

**How to run the check**

Use cached IDs from [Project configuration](#project-configuration) and `.agentia/config.json` (`context.pipelineId`, `context.sourceOrgId`, `context.sourceCredential`).

1. **Change-set analysis** (preferred when local files exist or are staged):

```sh

agentia metadata dependency list \

  --from-changes \

  --base-ref origin/main \

  --pipeline-id <pipelineId> \

  --source-org-id <sourceOrgId> \

  --source-credential-id <sourceCredentialId> \

  --target-org-id <targetOrgId> \

  --json

```

2. **Single-component analysis** (preferred **before implementation** when specs reference existing metadata not yet in the repo — e.g. an Apex class the new code will call):

```sh

agentia metadata dependency list \

  --metadata-name <ApiName> \

  --metadata-type <MetadataType> \

  --pipeline-id <pipelineId> \

  --source-org-id <sourceOrgId> \

  --source-credential-id <sourceCredentialId> \

  --json

```

MCP equivalent: `agentia_metadata_dependency_list` with the same IDs (use `metadataName` / `metadataType` for single-component checks).

**When dependencies are missing**

1. List each missing metadata item (type + API name) and why it is required.

2. **Retrieve from the source org** and add to the repo (`sf project retrieve start` or `agentia metadata content get` → write files under `force-app/`).

3. Include retrieved dependency files in the **same commit** as the dependent metadata — do not commit the consumer alone.

4. At the **before work ends** gate, missing dependencies are **not optional** — retrieve and add them unless the user explicitly declines after seeing the list.

5. If the user declines retrieval, **stop and warn** that promotion/deploy to environments without those dependencies will fail; do not push, submit, or mark work done.

**Common gaps agents miss**

- Apex classes referenced by new controllers/LWC but not in the branch (e.g. `WeatherService` required by `WeatherDisplayController`).

- Custom metadata types, fields, and **Default** records referenced in Apex.

- Named credentials / external credentials used in `callout:` endpoints.

- Permission sets, custom labels, or flows referenced by new UI — verify via dependency output, not guesswork.

### Mandatory: Agentia for ALM (no Salesforce CLI bypass)

**Always use Agentia** for Copado ALM / work-item operations. Do **not** substitute raw Salesforce CLI calls.

| Task | Use | Do **not** use |

| --- | --- | --- |

| Create user story / work item | `agentia work create --json` (or MCP `agentia_work_create`) | `sf data create record` on `copado__User_Story__c` |

| Update user story | `agentia work update [id] --json` (or MCP `agentia_work_update`) | `sf data update record` on `copado__User_Story__c` |

| Read user story | `agentia work get` / `agentia work list --json` | `sf data query` / `sf data get record` on Copado work objects |

| Delete user story | `agentia work delete <id>` (confirm first) | `sf data delete record` |

| Start work / feature branch | `agentia work set <id>` (or MCP `agentia_work_set`) | Manual branch checkout + Copado UI |

| Push commits to Copado | `agentia work push` (or MCP `agentia_work_push`) | Manual `git push` + Copado UI |

| Submit for validation | `agentia work submit` (confirm first; or MCP `agentia_work_submit`) | Copado UI promote action |

| Mark done / promote | `agentia work done` (confirm first; or MCP `agentia_work_done`) | Copado UI promote action |

Additional rules:

1. **Before creating work items**, read [Project configuration](#project-configuration) and run `agentia project default get --json`. If defaults are missing, set them with `agentia project default set` (see `.agentia/config.json`).

2. **Use cached IDs** from Project configuration and `.agentia/config.json` (`defaults` + `context`) for `work create`, pipeline, and metadata commands. Resolve gaps via [Resolving missing IDs](#resolving-missing-ids); do not invent Salesforce IDs.

3. **If Auto-review blocks** an `agentia work *` command, **request approval and retry the same command**. Never silently fall back to `sf data *` on Copado objects.

4. **MCP vs shell:** prefer MCP work tools when exposed by `agentia mcp start`; otherwise shell with `agentia … --json`.

---

## Full CLI command inventory

### `auth` — credentials (keychain)

| Command | Purpose |

| --- | --- |

| `agentia auth set` | Store CICD API key (`--cicd`), optional `--crt`, `--region` or `--custom-url` |

| `agentia auth get` | Show stored credentials (`--cicd` / `--crt` selectors). **Do not echo secrets to the user.** |

### `user`

| Command | Purpose |

| --- | --- |

| `agentia user get [ID]` | Get user by ID; defaults to authenticated user (`me`) |

### `project`

| Command | Purpose |

| --- | --- |

| `agentia project list` | List projects (`--mine`, `--name` optional) |

| `agentia project get ID` | Get a Copado project by ID (releases, settings) |

| `agentia project default get` | Show defaults (project, environment, team, sprint, epic, feature, assignMe); `--global` |

| `agentia project default set` | Set defaults (`--project`, `--environment`, `--team`, `--sprint`, `--epic`, `--feature`, `--assign-me`, `--global`) |

| `agentia project default unset` | Clear selected defaults |

Defaults map into user-story create payload:

| Default key | Work field |

| --- | --- |

| `project` | `project` |

| `environment` | `sourceEnvironment` |

| `team` | `team` |

| `sprint` | `sprintId` |

| `epic` | `epic` |

| `feature` | `feature` |

| `assignMe` | `assignee` (current user) |

### `environment`

| Command | Purpose |

| --- | --- |

| `agentia environment list` | List/filter environments |

| `agentia environment get ID` | Get environment |

| `agentia environment create NAME` | Create environment |

| `agentia environment update ID` | Update environment |

| `agentia environment auth status ID` | Validate credential auth (`--credentialid`) |

| `agentia environment auth web login ID` | Browser web login for credential (`--credentialid`, `--port`, `--timeout`) |

### `pipeline`

| Command | Purpose |

| --- | --- |

| `agentia pipeline list` | List pipelines (`--user-id`, `--organization-id`) |

| `agentia pipeline get ID` | Describe pipeline |

| `agentia pipeline connection list` | List connections (`--pipeline-id` optional) |

### `work` — user stories

| Command | Purpose |

| --- | --- |

| `agentia work list` | List/filter stories (`--name`, `--title`, `--status`, `--project-id`, `--project-name`, `--assignee-id`, `--assignee-name`, `--owner-id`, `--owner-name`, `--assigned-to-me`, `--owned-by-me`, …) |

| `agentia work get [ID]` | Full story header + specs + env/pipeline context; ID defaults to active work item from `work set` |

| `agentia work create` | Create story (mutation flags + project defaults) — **required for new work items** |

| `agentia work update [ID]` | Update story fields; ID defaults to active work item from `work set` |

| `agentia work delete ID` | Delete story (**confirm first**) |

| `agentia work set ID` | Set active work item; fetch base branch from `origin`, create/checkout `feature/<user-story-name>` (**clean working tree**) |

| `agentia work push` | Push current feature branch to `origin` and register commits with Copado (**clean working tree**, requires prior `work set`) |

| `agentia work submit` | Push when ahead of `origin`, then submit for pipeline quality gates / validation (`validate=true`) — **confirm first** |

| `agentia work done` | Push when ahead of `origin`, then mark done and promote to next environment (`validate=false`) — **confirm first** |

| `agentia work status [ID]` | Work item status plus related job executions; ID defaults to active work item from `work set` |

Important `work get` fields for agents:

- Specs: `functionalRequirements`, `technicalSpecifications`, `acceptanceCriteria`, `asA` / `wantTo` / `soThat`

- Context: `project`, `projectName`, `sourceEnvironment`, `sourceEnvironmentName`, `sourceCredential`, `sourceOrgId`, `pipelineId`, `status`, `components`, branches/release fields

Mutation flags (create/update) include: `--title`, `--status`, `--project`, `--source-environment`, `--source-credential`, `--functional-requirements`, `--technical-specifications`, `--acceptance-criteria`, `--as-a`, `--want-to`, `--so-that`, `--assignee`, `--owner-id`, `--team`, `--sprint-id`, `--epic`, `--feature`, `--theme`, `--priority`, `--planned-points`, `--actual-points`, `--release-id`, `--record-type`, `--close-date`, `--cancellation-reason`, `--excluded-from-cbm` / `--no-excluded-from-cbm`.

### `job` — job executions

| Command | Purpose |

| --- | --- |

| `agentia job list` | List jobs; filters: `--id`, `--status`, `--name`, `--type`, `--parent` (e.g. user story Id), `--context`, `--limit` + pipeline headers |

| `agentia job get ID` | Job + ordered steps (failure detail) |

| `agentia job log get ID` | Raw log output for a job step (`--step` optional; defaults to first step with a result ID) |

| `agentia job run ID` | Run all steps (`--restart` optional) |

| `agentia job resume ID` | Resume outstanding steps |

| `agentia job pause ID` | Pause (resumable cancel) |

| `agentia job kill ID` | Cancel (**confirm first**) |

### `metadata`

| Command | Purpose |

| --- | --- |

| `agentia metadata list` | Search metadata index |

| `agentia metadata content get` | Retrieve file content (`--api-name`, `--metadata-type`, `--source`, …) |

| `agentia metadata content compare` | Unified diff between orgs/branches |

| `agentia metadata index compare` | Index-level compare (`--comparison-mode`) |

| `agentia metadata dependency list` | Dependencies; supports `--from-changes`, `--base-ref`, `--stdin`, `--file`, `--retrieve-mode` |

| `agentia metadata refresh run` | Trigger index refresh (`--env`, pipeline/org/credential flags) |

| `agentia metadata refresh deleted` | Refresh deleted-metadata index |

| `agentia metadata refresh status` | Refresh job status (`--job-id`) |

### `promotion`

| Command | Purpose |

| --- | --- |

| `agentia promotion list` | List/filter promotions (pipeline, project, source/dest env, status, …) |

| `agentia promotion get ID` | Get promotion |

| `agentia promotion conflict list -p ID` | List merge conflicts |

| `agentia promotion conflict get ID -p ID` | Raw conflict content (`--output` file optional) |

| `agentia promotion conflict resolve ID -p ID` | Resolve (`--mode auto\|manual`, `--file` for manual) — **confirm** |

| `agentia promotion conflict unresolve ID -p ID` | Undo resolution — **confirm** |

### `mcp`

| Command | Purpose |

| --- | --- |

| `agentia mcp start` | Long-running MCP server over stdio (no `--json`) |

### Built-ins

- `agentia help [COMMAND]`

- `agentia plugins`

---

## MCP tools (prefer these)

JSON-safe; secrets redacted. Start `agentia mcp start` from the repo root when using Git-backed work tools.

| Topic | Tools |

| --- | --- |

| Auth | `agentia_auth_get`, `agentia_auth_set` |

| Environment | `agentia_environment_list`, `_get`, `_create`, `_update`, `_auth_status` |

| User | `agentia_user_get` |

| Project | `agentia_project_list`, `_get`, `agentia_project_default_get`, `_set`, `_unset` |

| Pipeline | `agentia_pipeline_list`, `_get`, `_connection_list` |

| Work | `agentia_work_list`, `_get`, `_create`, `_update`, `_delete`, `_set`, `_status`, `_push`, `_submit`, `_done` |

| Job | `agentia_job_list`, `_get`, `_log_get`, `_run`, `_resume`, `_pause`, `_kill` |

| Promotion | `agentia_promotion_list`, `_get`, `_conflict_list`, `_conflict_get`, `_conflict_resolve`, `_conflict_unresolve` |

| Metadata | `agentia_metadata_list`, `_content_get`, `_content_compare`, `_index_compare`, `_dependency_list`, `_refresh_run`, `_refresh_status`, `_refresh_deleted` |

### MCP notes

- Pipeline and job tools require `userId` and `organizationId` (gateway `x-user-id` / `x-organization-id` headers). Use cached values from [Project configuration](#project-configuration).

- `agentia_work_set`, `_push`, `_submit`, and `_done` operate on the MCP server's current Git repository and can fetch, check out, or push to `origin`.

- `agentia_work_get`, `_update`, and `_status` default to the active work item after `agentia_work_set`.

- `agentia_user_get` defaults `id` to `me` for the authenticated user.

- Promotion conflict resolve MCP tool uses `content` for manual mode (CLI uses `--file`).

- Metadata dependency MCP tool takes explicit `metadataName` / `metadataType`; CLI `--from-changes`, `--stdin`, and `--file` variants are richer for change-set analysis.

### CLI-only today (use shell + `--json`)

- `environment auth web login` (browser-based credential login)

- Metadata dependency `--from-changes`, `--base-ref`, `--stdin`, and `--file` input modes

---

## Recommended agent playbooks

### 1) Orient

1. Read [Project configuration](#project-configuration) and `.agentia/config.json` (`defaults` + `context`)

2. `agentia project default get --json` — confirm project/environment/team/sprint defaults align with config

3. If `context.sourceCredential`, `context.releaseId`, or `context.pipelineId` are empty, resolve via [Resolving missing IDs](#resolving-missing-ids) and update config

4. `agentia pipeline connection list --pipeline-id <pipelineId>` when you need branch/env mapping

### 2) Create a user story (work item)

1. Read [Project configuration](#project-configuration) and `agentia project default get --json`

2. If needed, `agentia project default set --project <id> --environment <id> --assign-me`

3. Create with **`agentia work create --json`** (never `sf data create record`). Pull IDs from config `context` and `defaults`:

```sh

agentia work create \

  --title "<title>" \

  --status Draft \

  --as-a "<role>" \

  --want-to "<need>" \

  --so-that "<reason>" \

  --functional-requirements "<specs>" \

  --technical-specifications "<tech specs>" \

  --acceptance-criteria "<criteria>" \

  --source-credential a11hm000000lAK5AAM \

  --release-id <release-id-from-context> \

  --record-type <record-type-from-context> \

  --json

```

4. Omit flags already covered by project defaults (`--project`, `--source-environment`, `--team`, `--sprint-id`, `--epic`, `--feature`, `--assignee` when `--assign-me` is set). Always include `--source-credential` from `context.sourceCredential`. Include `--release-id` when `context.releaseId` is set.

5. On success, report the returned story ID/name from JSON `result` — do not re-query via `sf`.

6. If the requested scope spans multiple metadata layers or is clearly an end-to-end feature, create it as a **parent/epic story** and document a **Suggested Child Story Breakdown** in `functionalRequirements` and/or `technicalSpecifications` (see [Large / epic user stories](#10-large--epic-user-stories)).

### 3) Understand a user story

1. `agentia work list` (e.g. assigned-to-me / name / status) → pick ID

2. `agentia work get <id>` (or `agentia work set <id>` then `agentia work get`)

3. Read `functionalRequirements` + `technicalSpecifications` (+ acceptance criteria) to decide changes

4. **Assess story size** using [Large / epic user stories](#10-large--epic-user-stories) — if it qualifies, stop and inform the user before writing code

5. Note `sourceEnvironment`, `sourceOrgId`, `sourceCredential`, `pipelineId` for later metadata/job calls

6. From specs, list metadata the story **consumes** (existing Apex, objects, credentials, etc.) — these are dependency-check inputs for playbook 4

7. If the user asked to **work on / implement / build / start** this story, proceed to playbook 4 — dependency checks are mandatory for that request

### 4) Start work + implement

Triggered whenever the user asks you to work on a user story, work item, or ticket.

1. Ensure a clean tracked working tree, then `agentia work set <id>` (or MCP `agentia_work_set`) — checks out `feature/<user-story-name>` from the Copado base branch

2. **Dependency check (entry — before coding):** for each metadata item the story will consume or extend, run [Mandatory: Metadata dependency check](#mandatory-metadata-dependency-check). Retrieve/include missing prerequisites **before** writing dependent metadata.

3. Make implementation changes

4. **Dependency check (before commit):** when the user asks for a commit (or before staging metadata for commit), run `--from-changes` against `origin/main`. If missing dependencies are detected and not included in the change set: retrieve/include them, re-run the check, then commit. **Never commit metadata that depends on org-only components without those dependencies in the same change set.**

5. Commit to Git when asked — only after step 4 passes or the user explicitly accepts documented gaps

6. **Dependency check (exit — before work ends):** run `--from-changes` on the full branch change set. **Retrieve and add** any dependencies still missing from the repo. Re-run until dependency-complete. Commit retrieved dependencies when the user asks for a commit (step 4 applies). **Do not** push, submit, report implementation complete, or mark the story done until this gate passes or the user explicitly accepts documented gaps.

7. `agentia work push` (or MCP `agentia_work_push`) to register commits with Copado — only after step 6 passes

### 5) Submit, done, and monitor

1. **Dependency check (exit gate):** re-run `--from-changes` and retrieve/add any missing dependencies before any pipeline action (same rules as playbook 4 step 6)

2. `agentia work status` (or MCP `agentia_work_status`) — story status plus related jobs; omit ID when active work item is set

3. `agentia work submit` — push if needed, then run pipeline quality gates (`validate=true`). **Confirm with the user first.** Only after the exit dependency gate passes.

4. `agentia job list --parent <userStoryId> …` → `agentia job get <id>` → `agentia job log get <id>` for step failures

5. `agentia work done` — push if needed, then promote to the next environment (`validate=false`). **Confirm with the user first.** Only after the exit dependency gate passes.

### 6) Dependency check only (no work set)

Use when the feature branch is already checked out and Copado registration is handled separately. Follow [Mandatory: Metadata dependency check](#mandatory-metadata-dependency-check) — same entry, commit, and **before work ends** rules apply.

### 7) Job lifecycle

1. `agentia job list --parent <userStoryId> …` (or name/status/context filters)

2. `agentia job get <id>` for step-level failure detail

3. `agentia job log get <id> [--step <step-id>]` for raw step logs

4. `agentia job run` / `resume` / `pause` / `kill` only with clear intent; confirm kill

### 8) Metadata impact / compare

1. `agentia metadata list` → filter type/name

2. `agentia metadata dependency list`

3. `agentia metadata content get` / `content compare` / `index compare` before promote

4. Refresh index with `agentia metadata refresh *` when index is stale

### 9) Promotion / conflicts

1. `agentia promotion list` / `agentia promotion get`

2. `agentia promotion conflict list -p <promotionId>`

3. `agentia promotion conflict get` → propose resolution

4. `agentia promotion conflict resolve` only with explicit approval (`--mode auto|manual`)

### 10) Large / epic user stories

Use this playbook when creating, reviewing, or being asked to **implement** a user story.

#### When a story is "too big"

Treat a user story as a **parent/epic** (not a single sprint item) when **any** of the following apply:

| Signal | Threshold |

| --- | --- |

| Metadata breadth | **≥ 4 distinct metadata types** (e.g. CustomObject + ApexClass + Flow + LWC) |

| Planned points | **≥ 13** planned points (Fibonacci) |

| Acceptance criteria | **≥ 6** distinct, testable scenarios |

| Functional scope | Multiple independent deliverables (data model + automation + UI + security + analytics) |

| Explicit markers | Specs mention "epic", "parent feature", "decompose", or include a numbered child-story breakdown |

| Cross-layer dependency | Changes require a strict deploy order across layers (objects → Apex → flows → UI → security) |

#### Mandatory: inform the user before implementing

When the user asks to **work on**, **implement**, **build**, or **start** a story that meets the criteria above:

1. **Do not begin implementation** on the full epic in one pass.

2. **Tell the user explicitly** that the story is too large for a single work item and should be broken down first. Include:

   - Story ID/name and why it qualifies (which signals matched)

   - The proposed child stories (title + metadata focus + suggested order)

   - A recommendation for which child story to implement first and why (usually data model / foundation)

3. **Ask how to proceed** — typical options:

   - Create child user stories in Copado (linked via `--epic` / `--feature` when IDs are known)

   - Implement one specific child story the user selects

   - Refine the breakdown before any coding starts

4. Only implement after the user confirms a **single, scoped child story** (or explicitly overrides and wants the full epic attempted — rare; warn about promotion/review risk).

Example user-facing message:

> **US-0000036** is an epic-level story (8+ metadata types, 21 points, 10 acceptance criteria). I recommend splitting it into 8 child stories before implementation. Suggested first slice: **US-001 — Custom fields + Health_Score_History__c**. Should I create the child stories in Copado, or start with US-001?

#### Breaking down a large story

1. `agentia work get <parent-id>` — read full specs

2. Derive **3–8 child stories**, each:

   - Completable in one sprint / one promotion

   - Scoped to **1–2 metadata layers** where possible

   - Ordered by dependency (foundation first: objects/fields → logic → UI → security → analytics)

   - Given its own acceptance criteria (2–4 scenarios, not the full epic list)

3. Create children with **`agentia work create --json`** (or MCP `agentia_work_create`):

   - Set `--epic` or `--feature` to the parent when those fields are populated on the parent story

   - Reference the parent story ID/name in each child's `functionalRequirements` (e.g. "Child of US-0000036 — slice 1/8")

   - Copy only the relevant subset of specs and acceptance criteria into each child

4. Leave the **parent story in Draft** (or a dedicated epic status if the project uses one) until all children are Done

5. Report created child story IDs/names to the user

#### Child story sizing guide

| Child story should include | Child story should NOT include |

| --- | --- |

| One cohesive slice (e.g. "data model only" or "one LWC + flexipage") | Unrelated metadata from another layer "while we're at it" |

| 2–4 acceptance criteria | The full epic's 10+ criteria copied verbatim |

| 3–8 planned points | Entire platform / multi-app delivery |

| Clear deploy boundary | "And also build the dashboard and reports" unless that _is_ the slice |

---

## Output contract

- Success: JSON with `status: 0` and `result`

- Failure: non-zero / `error.message` — surface API text to the user

- MCP tools return structured tool results (same domain payloads, redacted)
