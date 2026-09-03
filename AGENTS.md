# AGENTS.md — Development flow

Use **Agentia CLI** for all ALM and metadata work. Do **not** use Agentia MCP.
When implementing the US, do not check for data templates and related data unless specifically asked

---

## Understand a user story

1. Use Agentia CLI and not Agentia MCP.
2. Use `agentia work cicd get <userstoryid>` — read specs, acceptance criteria.

---

## Implement

1. **Existing org metadata (mandatory before any local edit)** — if metadata exists in the source org, treat the **org** as source of truth, not the repo copy.
   - Check org presence (`agentia_metadata_list` / `agentia metadata list --json`).
   - Retrieve with `agentia_metadata_content_get` / `agentia metadata content get --json`, write under `force-app/`, then apply story changes on that retrieved copy.
   - **Never** edit a repo file blindly when the same component exists in the org — org-only changes (e.g. Lightning App Builder field additions) are lost on deploy.
2. Implement Salesforce metadata under `force-app/`. Author files directly or retrieve existing org metadata via Agentia — never use `sf template generate` or other `sf` commands to scaffold metadata.
3. **Stage changes** — after dry-run succeeds, `git add` relevant files under `force-app/`. Do not commit yet.
4. Commit the changes using `agentia cicd work commit`.

---

## Submit, done, monitor

1. Confirm dry-run validation, pre- and post-deploy dependency resolve, and source-org deploy already passed (re-run only if changes or retrieved deps changed).d
2. `agentia_work_status` / `agentia work status` — story + related jobs.
3. `agentia work submit` — validation (`validate=true`). **Confirm with user first.**
4. On failure: `agentia job list` → `job get` → `job log get`.
5. `agentia work done` — promote (`validate=false`). **Confirm with user first.**
