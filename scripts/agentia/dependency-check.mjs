#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "../..");
const MAX_RESOLVE_ITERATIONS = 10;

const STANDARD_OBJECTS = new Set([
  "Account",
  "Asset",
  "Campaign",
  "Case",
  "Contact",
  "Contract",
  "Lead",
  "Opportunity",
  "Order",
  "Product2",
  "User",
]);

function parseArgs(argv) {
  const args = {
    baseRef: null,
    targetOrgId: null,
    json: false,
    dryRun: false,
    resolve: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--json") {
      args.json = true;
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    } else if (arg === "--resolve") {
      args.resolve = true;
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

Map local git changes to metadata selections and call
agentia metadata dependency list --stdin (source org vs next pipeline org).

Dependencies are discovered by Agentia only. Use --resolve to retrieve every
retrievable dependency Agentia reports as MISSING in the target org.

Options:
  --resolve               Retrieve Agentia MISSING deps into force-app/ and loop
  --base-ref <ref>        Base git ref (default: origin/<lastBaseBranch>)
  --target-org-id <id>    Destination org Id (auto-resolved when omitted)
  --json                  Print Agentia or resolve summary as JSON
  --dry-run               Print request JSON only; do not call Agentia
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
  const diffFiles = runGit(repoRoot, ["diff", "--name-only", baseRef])
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
  if (path.endsWith(".flexipage-meta.xml") && path.includes("/flexipages/")) {
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

function selectionsFromFiles(files) {
  const byKey = new Map();

  for (const file of files) {
    const selection = resolveSalesforceSelection(file);
    if (selection) {
      byKey.set(`${selection.type}:${selection.name}`, selection);
    }
  }

  return [...byKey.values()];
}

function mergeSelections(...lists) {
  const byKey = new Map();
  for (const list of lists) {
    for (const selection of list) {
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

function runDependencyList(request) {
  const requestJson = `${JSON.stringify(request, null, 2)}\n`;
  const result = spawnSync(
    "agentia",
    ["metadata", "dependency", "list", "--stdin", "--json"],
    {
      cwd: repoRoot,
      input: requestJson,
      encoding: "utf8",
    }
  );

  if (result.status !== 0) {
    if (result.stderr) {
      process.stderr.write(result.stderr);
    }
    throw new Error(
      result.stderr?.trim() || "agentia metadata dependency list failed"
    );
  }

  return JSON.parse(result.stdout);
}

function dependencySelections(response) {
  const selections = [];
  for (const item of response?.result?.dependencies ?? []) {
    selections.push({ name: item.n, type: item.t });
    for (const dep of item.d ?? []) {
      selections.push({ name: dep.n, type: dep.t });
    }
  }
  return selections;
}

function collectMissingDependencies(response) {
  const missing = [];
  for (const item of response?.result?.dependencies ?? []) {
    for (const dep of item.d ?? []) {
      if (dep.s === "MISSING") {
        missing.push({ name: dep.n, type: dep.t });
      }
    }
  }
  return missing;
}

function isIgnoredMissing(type, name) {
  if (type === "FlexiPage" && name.startsWith("flexipage:")) {
    return true;
  }
  if (type === "CustomObject" && STANDARD_OBJECTS.has(name)) {
    return true;
  }
  return false;
}

function localMetadataPath(type, apiName) {
  if (type === "CustomField") {
    const [objectName, fieldName] = apiName.split(".");
    return join(
      repoRoot,
      "force-app/main/default/objects",
      objectName,
      "fields",
      `${fieldName}.field-meta.xml`
    );
  }
  if (type === "ApexClass") {
    return join(repoRoot, "force-app/main/default/classes", `${apiName}.cls`);
  }
  if (type === "LightningComponentBundle") {
    return join(
      repoRoot,
      "force-app/main/default/lwc",
      apiName,
      `${apiName}.js`
    );
  }
  return null;
}

function metadataExistsLocally(type, apiName) {
  const path = localMetadataPath(type, apiName);
  return path ? existsSync(path) : false;
}

function retrievableMissing(missing) {
  const byKey = new Map();
  for (const dep of missing) {
    if (isIgnoredMissing(dep.type, dep.name)) {
      continue;
    }
    if (metadataExistsLocally(dep.type, dep.name)) {
      continue;
    }
    byKey.set(`${dep.type}:${dep.name}`, dep);
  }
  return [...byKey.values()];
}

function normalizeCustomFieldXml(content, apiName) {
  const [, fieldName] = apiName.split(".");
  return content.replace(
    new RegExp(`<fullName>${apiName.replace(".", "\\.")}</fullName>`),
    `<fullName>${fieldName}</fullName>`
  );
}

function retrieveMetadata(config, type, apiName) {
  const { context } = config;
  const response = runAgentiaJson([
    "metadata",
    "content",
    "get",
    "--metadata-type",
    type,
    "--api-name",
    apiName,
    "--pipeline-id",
    context.pipelineId,
    "--source",
    "ENVIRONMENT",
    "--source-org-id",
    context.sourceOrgId,
    "--source-credential-id",
    context.sourceCredential,
    "--json",
  ]);

  const record = response.records?.[0];
  if (!record?.contentBase64) {
    throw new Error(`Metadata not found in source org: ${type} ${apiName}`);
  }

  return Buffer.from(record.contentBase64, "base64").toString("utf8");
}

function writeRetrievedMetadata(type, apiName, content) {
  const written = [];

  if (type === "CustomField") {
    const outputPath = localMetadataPath(type, apiName);
    mkdirSync(dirname(outputPath), { recursive: true });
    writeFileSync(
      outputPath,
      `${normalizeCustomFieldXml(content, apiName).trim()}\n`,
      "utf8"
    );
    written.push(outputPath.replace(`${repoRoot}/`, ""));
    return written;
  }

  if (type === "ApexClass") {
    const classPath = localMetadataPath(type, apiName);
    mkdirSync(dirname(classPath), { recursive: true });
    writeFileSync(classPath, `${content.trim()}\n`, "utf8");
    written.push(classPath.replace(`${repoRoot}/`, ""));

    const metaPath = `${classPath}-meta.xml`;
    if (!existsSync(metaPath)) {
      writeFileSync(
        metaPath,
        `<?xml version="1.0" encoding="UTF-8"?>\n<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">\n    <apiVersion>64.0</apiVersion>\n    <status>Active</status>\n</ApexClass>\n`,
        "utf8"
      );
      written.push(metaPath.replace(`${repoRoot}/`, ""));
    }
    return written;
  }

  throw new Error(
    `Auto-retrieve not supported for ${type} ${apiName}. Use agentia metadata content get manually.`
  );
}

function stagePaths(paths) {
  if (paths.length > 0) {
    runGit(repoRoot, ["add", ...paths]);
  }
}

function resolveDependencies(config, baseRef, targetOrgId, printJson) {
  const retrieved = [];
  let iterations = 0;
  let lastResponse = null;
  let remainingMissing = [];
  let agentiaSelections = [];

  while (iterations < MAX_RESOLVE_ITERATIONS) {
    iterations += 1;
    const files = changedForceAppFiles(baseRef);
    if (files.length === 0) {
      throw new Error(`No local force-app/ changes found against ${baseRef}.`);
    }

    const selections = mergeSelections(
      selectionsFromFiles(files),
      agentiaSelections
    );
    const request = buildRequest(config, selections, targetOrgId);
    lastResponse = runDependencyList(request);
    agentiaSelections = mergeSelections(
      agentiaSelections,
      dependencySelections(lastResponse)
    );

    remainingMissing = retrievableMissing(
      collectMissingDependencies(lastResponse)
    );

    if (remainingMissing.length === 0) {
      break;
    }

    let retrievedThisPass = 0;
    for (const dep of remainingMissing) {
      try {
        const content = retrieveMetadata(config, dep.type, dep.name);
        const paths = writeRetrievedMetadata(dep.type, dep.name, content);
        stagePaths(paths);
        retrieved.push({ type: dep.type, name: dep.name, paths });
        agentiaSelections = mergeSelections(agentiaSelections, [dep]);
        retrievedThisPass += 1;
      } catch (error) {
        process.stderr.write(
          `Could not retrieve ${dep.type} ${dep.name}: ${error.message}\n`
        );
      }
    }

    if (retrievedThisPass === 0) {
      break;
    }
  }

  const summary = {
    status: remainingMissing.length === 0 ? 0 : 1,
    iterations,
    retrieved,
    remainingMissing,
    dependencies: lastResponse?.result?.dependencies ?? [],
  };

  if (printJson) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  } else {
    process.stdout.write("Dependency resolve summary:\n");
    process.stdout.write(`  iterations: ${iterations}\n`);
    process.stdout.write(`  retrieved: ${retrieved.length}\n`);
    for (const item of retrieved) {
      process.stdout.write(`    - ${item.type} ${item.name}\n`);
    }
    process.stdout.write(`  remaining missing: ${remainingMissing.length}\n`);
    for (const item of remainingMissing) {
      process.stdout.write(`    - ${item.type} ${item.name}\n`);
    }
  }

  if (summary.status !== 0) {
    process.exit(1);
  }
}

function changedForceAppFiles(baseRef) {
  return changedFiles(baseRef).filter((file) => file.startsWith("force-app/"));
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    process.stdout.write(usage());
    return;
  }

  const config = loadConfig();
  const baseRef = args.baseRef ?? defaultBaseRef(config);
  const files = changedForceAppFiles(baseRef);

  if (files.length === 0) {
    throw new Error(
      `No local force-app/ changes found against ${baseRef}. Nothing to check.`
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

  if (args.resolve) {
    if (args.dryRun) {
      const selections = mergeSelections(selectionsFromFiles(files), []);
      process.stdout.write(
        `${JSON.stringify(buildRequest(config, selections, targetOrgId ?? "<targetOrgId>"), null, 2)}\n`
      );
      return;
    }
    resolveDependencies(config, baseRef, targetOrgId, args.json);
    return;
  }

  const selections = selectionsFromFiles(files);
  if (selections.length === 0) {
    throw new Error(
      "No resolvable metadata selections were found from local force-app/ changes."
    );
  }

  const request = buildRequest(
    config,
    selections,
    targetOrgId ?? "<targetOrgId>"
  );

  if (args.dryRun) {
    process.stdout.write(`${JSON.stringify(request, null, 2)}\n`);
    return;
  }

  const response = runDependencyList(request);
  process.stdout.write(`${JSON.stringify(response, null, 2)}\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
}
