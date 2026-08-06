#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "../..");

function parseArgs(argv) {
  const args = {
    baseRef: null,
    targetOrgId: null,
    json: false,
    dryRun: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--json") {
      args.json = true;
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    } else if (arg === "--help" || arg === "-h") {
      args.help = true;
    } else if (arg === "--base-ref") {
      args.baseRef = argv[++i];
    } else if (arg === "--target-org-id") {
      args.targetOrgId = argv[++i];
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function usage() {
  return `Usage: node scripts/agentia/dependency-check.mjs [options]

Build a dependency request from local git changes (staged, unstaged, and
untracked) and run agentia metadata dependency list --stdin.

Options:
  --base-ref <ref>        Base git ref (default: origin/<lastBaseBranch>)
  --target-org-id <id>    Destination org Id (auto-resolved when omitted)
  --json                  Pass --json to agentia
  --dry-run               Print request JSON only; do not call agentia
  -h, --help              Show this help
`;
}

function runGit(cwd, gitArgs) {
  return execFileSync("git", gitArgs, { cwd, encoding: "utf8" }).trim();
}

function loadConfig() {
  const configPath = join(repoRoot, ".agentia/config.json");
  return JSON.parse(readFileSync(configPath, "utf8"));
}

function defaultBaseRef(config) {
  const branch = config.lastBaseBranch || "main";
  return `origin/${branch}`;
}

function changedFiles(baseRef) {
  const diffFiles = runGit(repoRoot, [
    "diff",
    "--name-only",
    baseRef,
  ])
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  const untrackedFiles = runGit(repoRoot, [
    "ls-files",
    "--others",
    "--exclude-standard",
  ])
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return [...new Set([...diffFiles, ...untrackedFiles])];
}

function fileBaseName(path, suffix) {
  const name = path.split("/").pop() ?? path;
  return name.endsWith(suffix) ? name.slice(0, -suffix.length) : name;
}

function parentDirectory(path) {
  const parts = path.split("/");
  return parts.length > 1 ? (parts.at(-2) ?? "") : "";
}

function resolveSalesforceSelection(path) {
  if (path.endsWith(".cls") && path.includes("/classes/")) {
    return { name: fileBaseName(path, ".cls"), type: "ApexClass" };
  }
  if (path.endsWith(".trigger") && path.includes("/triggers/")) {
    return { name: fileBaseName(path, ".trigger"), type: "ApexTrigger" };
  }
  if (path.includes("/lwc/")) {
    return { name: parentDirectory(path), type: "LightningComponentBundle" };
  }
  if (path.includes("/aura/")) {
    return { name: parentDirectory(path), type: "AuraDefinitionBundle" };
  }
  if (path.endsWith(".flow-meta.xml") && path.includes("/flows/")) {
    return { name: fileBaseName(path, ".flow-meta.xml"), type: "Flow" };
  }
  if (path.endsWith(".layout-meta.xml") && path.includes("/layouts/")) {
    return { name: fileBaseName(path, ".layout-meta.xml"), type: "Layout" };
  }
  if (
    path.endsWith(".permissionset-meta.xml") &&
    path.includes("/permissionsets/")
  ) {
    return {
      name: fileBaseName(path, ".permissionset-meta.xml"),
      type: "PermissionSet",
    };
  }
  if (
    path.endsWith(".flexipage-meta.xml") &&
    path.includes("/flexipages/")
  ) {
    return {
      name: fileBaseName(path, ".flexipage-meta.xml"),
      type: "FlexiPage",
    };
  }

  const objectMatch = path.match(/\/objects\/([^/]+)\/\1\.object-meta\.xml$/);
  if (objectMatch) {
    return { name: objectMatch[1], type: "CustomObject" };
  }

  const fieldMatch = path.match(
    /\/objects\/([^/]+)\/fields\/([^/]+)\.field-meta\.xml$/
  );
  if (fieldMatch) {
    return {
      name: `${fieldMatch[1]}.${fieldMatch[2]}`,
      type: "CustomField",
    };
  }

  return undefined;
}

function resolveChangedPath(path) {
  if (path.endsWith("-meta.xml") && !path.includes("/objects/")) {
    return resolveSalesforceSelection(path);
  }
  return resolveSalesforceSelection(path);
}

function selectionsFromFiles(files) {
  const byKey = new Map();

  for (const file of files) {
    const selection = resolveChangedPath(file);
    if (selection) {
      byKey.set(`${selection.type}:${selection.name}`, selection);
    }
  }

  return [...byKey.values()];
}

function runAgentiaJson(args) {
  const output = execFileSync("agentia", args, {
    cwd: repoRoot,
    encoding: "utf8",
  });
  return JSON.parse(output);
}

function resolveTargetOrgId(pipelineId, sourceOrgId) {
  const response = runAgentiaJson([
    "pipeline",
    "connection",
    "list",
    "--pipeline-id",
    pipelineId,
    "--json",
  ]);

  const connections = Array.isArray(response.result)
    ? response.result
    : (response.connections ?? response.result?.connections ?? []);

  const match = connections.find(
    (connection) => connection.sourceEnvironment?.orgId === sourceOrgId
  );

  if (!match?.destinationEnvironment?.orgId) {
    throw new Error(
      `Could not resolve destination org for source org ${sourceOrgId}. Pass --target-org-id explicitly.`
    );
  }

  return match.destinationEnvironment.orgId;
}

function buildRequest(config, selections, targetOrgId) {
  const { context } = config;

  return {
    platformExperience: "sfdx",
    pipelineId: context.pipelineId,
    compareOptions: {
      sourceOrgId: context.sourceOrgId,
      sourceCredentialId: context.sourceCredential,
      targetOrgId,
      retrieveMode: "diff_only",
    },
    metadataSelections: selections.map(({ name, type }) => ({ name, type })),
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    process.stdout.write(usage());
    return;
  }

  const config = loadConfig();
  const baseRef = args.baseRef ?? defaultBaseRef(config);
  const files = changedFiles(baseRef);

  if (files.length === 0) {
    throw new Error(`No local changes found against ${baseRef}.`);
  }

  const selections = selectionsFromFiles(files);
  if (selections.length === 0) {
    throw new Error(
      "No resolvable metadata selections were found from local changes."
    );
  }

  const targetOrgId =
    args.targetOrgId ??
    (args.dryRun
      ? null
      : resolveTargetOrgId(
          config.context.pipelineId,
          config.context.sourceOrgId
        ));

  if (!targetOrgId && !args.dryRun) {
    throw new Error(
      "Destination org Id is required. Pass --target-org-id or ensure pipeline connections are configured."
    );
  }

  const request = buildRequest(config, selections, targetOrgId ?? "<targetOrgId>");
  const requestJson = `${JSON.stringify(request, null, 2)}\n`;

  if (args.dryRun) {
    process.stdout.write(requestJson);
    return;
  }

  const agentiaArgs = ["metadata", "dependency", "list", "--stdin"];
  if (args.json) {
    agentiaArgs.push("--json");
  }

  const result = spawnSync("agentia", agentiaArgs, {
    cwd: repoRoot,
    input: requestJson,
    encoding: "utf8",
  });

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
}
