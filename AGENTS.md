rage via git commands itself. Like for example, create branch from main and create feature branch, once changes are done, commit using git add on feature branch. SOmething like this



Current agents.md file:

# AGENTS.md — Agentia CLI (`agentia`)



Headless CICD CLI for Salesforce ALM / DevOps agent workflows.

Prefer **MCP tools** (`agentia mcp start`) when available; otherwise shell with **`--json`**.

Always invoke commands as `agentia …` (on PATH).



---



## Setup (human / CI — not the agent)



```sh

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



Optional project defaults (used by `work create`):



```sh

agentia project default set --project <id> --environment <id> --team <id> --sprint <id> --assign-me

agentia project default get --json

```



### Project context (this repo)



Cached IDs for pipeline / job commands. Use these directly — do not re-resolve via `sf org display` unless auth or org changes.



| Field | Value |

| --- | --- |

| Organization ID | `00DdN000011i71VUAQ` |

| User ID | `005dN00000DA8PpQAL` |

| Username | `nvijay+aug2026@copado.com` |

| SF org alias | `AgentforceHeadless` |



CLI example:



```sh

agentia pipeline list \

  --user-id 005dN00000DA8PpQAL \

  --organization-id 00DdN000011i71VUAQ \

  --json

```



MCP: pass `userId` and `organizationId` with the same values.



Also see `.agentia/config.json` for project/environment defaults.



---



## Global rules



- Almost all commands support `--json` → `{ status, result }` (or `{ error }`). Prefer JSON; do not parse tables/spinners.

- Pipeline / job commands need `--user-id` and `--organization-id` (MCP: `userId`, `organizationId`). **Use the cached values in [Project context](#project-context-this-repo) above.**

- Metadata inspect/compare/deps typically need `--pipeline-id`, `--source-org-id`, `--source-credential-id` (+ target/branch as needed).

- Never print secrets from `auth get`. Do not expose keychain material.

- Confirm before destructive ops: `job kill`, `work delete`, conflict resolve/unresolve.

- **Large user stories:** before implementing any work item, assess size per [Large / epic user stories](#8-large--epic-user-stories). If it qualifies as an epic, **inform the user and propose a breakdown** — do not implement the full scope in one pass unless the user explicitly overrides.



### Mandatory: Agentia for ALM (no Salesforce CLI bypass)



**Always use Agentia** for Copado ALM / work-item operations. Do **not** substitute raw Salesforce CLI calls.



| Task | Use | Do **not** use |

| --- | --- | --- |

| Create user story / work item | `agentia work create --json` (or MCP `agentia_work_create` when available) | `sf data create record` on `copado__User_Story__c` |

| Update user story | `agentia work update <id> --json` (or MCP `agentia_work_update`) | `sf data update record` on `copado__User_Story__c` |

| Read user story | `agentia work get` / `agentia work list --json` | `sf data query` / `sf data get record` on Copado work objects |

| Delete user story | `agentia work delete <id>` (confirm first) | `sf data delete record` |



Additional rules:



1. **Before creating work items**, run `agentia project default get --json`. If project/environment defaults are missing, set them with `agentia project default set` (see `.agentia/config.json` in this repo).

2. **Use cached org/user IDs** from [Project context](#project-context-this-repo) for pipeline/job commands. Resolve other IDs through Agentia (`project list`, `environment list`, `work get`) when needed.

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

| `agentia project list` | List projects (`--mine` optional) |

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

| `agentia work get ID` | Full story header + specs + env/pipeline context |

| `agentia work create` | Create story (mutation flags + project defaults) — **required for new work items** |

| `agentia work update ID` | Update story fields |

| `agentia work delete ID` | Delete story (**confirm first**) |



Important `work get` fields for agents:



- Specs: `functionalRequirements`, `technicalSpecifications`, `acceptanceCriteria`, `asA` / `wantTo` / `soThat`

- Context: `project`, `projectName`, `sourceEnvironment`, `sourceEnvironmentName`, `sourceCredential`, `sourceOrgId`, `pipelineId`, `status`, `components`, branches/release fields



Mutation flags (create/update) include: `--title`, `--status`, `--project`, `--source-environment`, `--source-credential`, `--functional-requirements`, `--technical-specifications`, `--acceptance-criteria`, `--as-a`, `--want-to`, `--so-that`, `--assignee`, `--owner-id`, `--team`, `--sprint-id`, `--epic`, `--feature`, `--theme`, `--priority`, `--planned-points`, `--actual-points`, `--release-id`, `--record-type`, `--close-date`, `--cancellation-reason`, `--excluded-from-cbm` / `--no-excluded-from-cbm`.



### `job` — job executions



| Command | Purpose |

| --- | --- |

| `agentia job list` | List jobs; filters: `--id`, `--status`, `--name`, `--type`, `--parent` (e.g. user story Id), `--context`, `--limit` + pipeline headers |

| `agentia job get ID` | Job + ordered steps (failure detail) |

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



JSON-safe; secrets redacted.



| Topic | Tools |

| --- | --- |

| Environment | `agentia_environment_list`, `_get`, `_create`, `_update` |

| User | `agentia_user_get` |

| Project | `agentia_project_list`, `agentia_project_default_get`, `_set`, `_unset` |

| Pipeline | `agentia_pipeline_list`, `_get`, `_connection_list` |

| Work | `agentia_work_list`, `_get`, `_create`, `_update`, `_delete` |

| Job | `agentia_job_list`, `_get`, `_run`, `_resume`, `_pause`, `_kill` |

| Promotion | `agentia_promotion_list`, `_get` |

| Metadata | `agentia_metadata_list`, `_content_get`, `_content_compare`, `_index_compare`, `_dependency_list` |



### CLI-only today (use shell + `--json`)



- `auth *`

- `environment auth status|web login`

- `metadata refresh *`

- `promotion conflict *` (list/get/resolve/unresolve)

- Dependency `--from-changes` / stdin / file variants are richer on CLI than the MCP dependency tool (MCP takes explicit name/type selections)



---



## Recommended agent playbooks



### 1) Orient



1. Read [Project context](#project-context-this-repo) for `organizationId` / `userId`; read `.agentia/config.json` for project/environment defaults

2. `agentia project default get --json` / `agentia project list` / `agentia environment list`

3. `agentia pipeline list` (with cached org/user IDs) + `agentia pipeline connection list` → cache pipeline/credential/env IDs

4. Do not invent Salesforce IDs



### 2) Create a user story (work item)



1. `agentia project default get --json` — confirm `project` and `environment` defaults (and optional team/sprint/assignMe)

2. If needed, `agentia project default set --project <id> --environment <id> --assign-me`

3. Create with **`agentia work create --json`** (never `sf data create record`):



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

  --source-credential <credential-id> \

  --release-id <release-id> \

  --record-type <record-type-id> \

  --json

```



4. Omit flags already covered by project defaults (`--project`, `--source-environment`, `--team`, `--sprint-id`, `--assignee` when `--assign-me` is set).

5. On success, report the returned story ID/name from JSON `result` — do not re-query via `sf`.

6. If the requested scope spans multiple metadata layers or is clearly an end-to-end feature, create it as a **parent/epic story** and document a **Suggested Child Story Breakdown** in `functionalRequirements` and/or `technicalSpecifications` (see [Large / epic user stories](#8-large--epic-user-stories)).



### 3) Understand a user story



1. `agentia work list` (e.g. assigned-to-me / name / status) → pick ID

2. `agentia work get <id>`

3. Read `functionalRequirements` + `technicalSpecifications` (+ acceptance criteria) to decide changes

4. **Assess story size** using [§8 Large / epic user stories](#8-large--epic-user-stories) — if it qualifies, stop and inform the user before writing code

5. Note `sourceEnvironment`, `sourceOrgId`, `sourceCredential`, `pipelineId` for later metadata/job calls



### 4) Implement + dependency check



1. Make implementation changes and commit to Git when asked

2. `agentia metadata dependency list --from-changes --base-ref origin/main --pipeline-id … --source-org-id … --source-credential-id … --target-org-id … --json`

3. If missing dependencies are detected and not included in the change set: notify as missing on destination and offer to retrieve/include them



### 5) Job lifecycle



1. `agentia job list --parent <userStoryId> …` (or name/status/context filters)

2. `agentia job get <id>` for step-level failure detail

3. `agentia job run` / `resume` / `pause` / `kill` only with clear intent; confirm kill



### 6) Metadata impact / compare



1. `agentia metadata list` → filter type/name

2. `agentia metadata dependency list`

3. `agentia metadata content get` / `content compare` / `index compare` before promote

4. Refresh index with `agentia metadata refresh *` when index is stale



### 7) Promotion / conflicts



1. `agentia promotion list` / `agentia promotion get`

2. `agentia promotion conflict list -p <promotionId>`

3. `agentia promotion conflict get` → propose resolution

4. `agentia promotion conflict resolve` only with explicit approval (`--mode auto|manual`)



### 8) Large / epic user stories



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

| Clear deploy boundary | "And also build the dashboard and reports" unless that *is* the slice |



---



## Output contract



- Success: JSON with `status: 0` and `result`

- Failure: non-zero / `error.message` — surface API text to the user

- MCP tools return structured tool results (same domain payloads, redacted)

I'll review your AGENTS.md and the repo's git workflow so we can document the commit process accurately.

Adding a Git workflow section to your Agentia AGENTS.md, aligned with Copado's branch model and local git commands.

# AGENTS.md — Agentia CLI (`agentia`)
Headless CICD CLI for Salesforce ALM / DevOps agent workflows.
Prefer **MCP tools** (`agentia mcp start`) when available; otherwise shell with **`--json`**.
Fixing section cross-reference numbering.

- Metadata inspect/compare/deps typically need `--pipeline-id`, `--source-org-id`, `--source-credential-id` (+ target/branch as needed).
- Never print secrets from `auth get`. Do not expose keychain material.
- Confirm before destructive ops: `job kill`, `work delete`, conflict resolve/unresolve.
- **Large user stories:** before implementing any work item, assess size per [Large / epic user stories](#9-large--epic-user-stories). If it qualifies as an epic, **inform the user and propose a breakdown** — do not implement the full scope in one pass unless the user explicitly overrides.
- **Large user stories:** before implementing any work item, assess size per [Large / epic user stories](#8-large--epic-user-stories). If it qualifies as an epic, **inform the user and propose a breakdown** — do not implement the full scope in one pass unless the user explicitly overrides.
### Mandatory: Agentia for ALM (no Salesforce CLI bypass)
5. On success, report the returned story ID/name from JSON `result` — do not re-query via `sf`.
6. If the requested scope spans multiple metadata layers or is clearly an end-to-end feature, create it as a **parent/epic story** and document a **Suggested Child Story Breakdown** in `functionalRequirements` and/or `technicalSpecifications` (see [Large / epic user stories](#9-large--epic-user-stories)).
6. If the requested scope spans multiple metadata layers or is clearly an end-to-end feature, create it as a **parent/epic story** and document a **Suggested Child Story Breakdown** in `functionalRequirements` and/or `technicalSpecifications` (see [Large / epic user stories](#8-large--epic-user-stories)).
3. Read `functionalRequirements` + `technicalSpecifications` (+ acceptance criteria) to decide changes
4. **Assess story size** using [§9 Large / epic user stories](#9-large--epic-user-stories) — if it qualifies, stop and inform the user before writing code
4. **Assess story size** using [§8 Large / epic user stories](#8-large--epic-user-stories) — if it qualifies, stop and inform the user before writing code
5. Note `sourceEnvironment`, `sourceOrgId`, `sourceCredential`, `pipelineId` for later metadata/job calls
I've added a Git workflow section to your Agentia AGENTS.md and saved the full file as AGENTS-agentia.md in your workspace (your existing root AGENTS.md is the Copado monorepo guide, so this keeps them separate).

What was added
1. Git vs Copado commit job table (under Global rules)
Clarifies when to use git vs Agentia/Copado jobs.

2. Git workflow (local commits) section — the main addition:

Topic