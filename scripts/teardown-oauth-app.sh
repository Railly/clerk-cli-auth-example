#!/usr/bin/env bash
set -euo pipefail

DEFAULT_NAME="cli-auth-local-test"
SDK_REPO="/Users/raillyhugo/Programming/railly/clerk-cli-auth"
CLERK_CLI_REPO="${CLERK_CLI_REPO:-/Users/raillyhugo/Clerk/cli}"
CLERK_CLI_CORE="$CLERK_CLI_REPO/packages/cli-core"

NAME="$DEFAULT_NAME"
CLIENT_ID=""
INSTANCE=""
APPLY=0

usage() {
  cat <<'USAGE'
Usage: scripts/teardown-oauth-app.sh [flags]

Flags:
  --client-id <id>        Delete the OAuth Application with this client_id.
  --name <app name>       Lookup by OAuth Application name. Default: cli-auth-local-test
  --instance <id>         Optional instance id or environment alias. If omitted,
                          the single development instance from `clerk apps list`
                          is selected.
  --apply                 Delete the OAuth Application. Default is dry-run.
  -h, --help              Show this help.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

shell_join() {
  local out="" arg
  for arg in "$@"; do
    if [ -n "$out" ]; then
      out+=" "
    fi
    printf -v arg "%q" "$arg"
    out+="$arg"
  done
  printf '%s\n' "$out"
}

clerk_cmd() {
  if command -v clerk >/dev/null 2>&1; then
    clerk --mode agent "$@"
  else
    bun run --cwd "$CLERK_CLI_CORE" src/cli.ts --mode agent "$@"
  fi
}

print_clerk_cmd() {
  if command -v clerk >/dev/null 2>&1; then
    shell_join clerk --mode agent "$@"
  else
    shell_join bun run --cwd "$CLERK_CLI_CORE" src/cli.ts --mode agent "$@"
  fi
}

require_apply_prereqs() {
  command -v bun >/dev/null 2>&1 || die "bun is required"
  command -v node >/dev/null 2>&1 || die "node is required for JSON parsing"
  [ -d "$SDK_REPO" ] || die "SDK repo not found: $SDK_REPO"
  [ -d "$CLERK_CLI_CORE" ] || die "Hunter's Clerk CLI repo not found: $CLERK_CLI_CORE"
}

urlencode() {
  node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$1"
}

resolve_target() {
  local apps_json
  if ! apps_json="$(clerk_cmd apps list --json 2>&1)"; then
    printf '%s\n' "$apps_json" >&2
    die "failed to list Clerk applications; run Hunter's CLI auth flow first"
  fi

  APPS_JSON="$apps_json" node - "$INSTANCE" <<'NODE'
const input = process.env.APPS_JSON || "";
const requested = process.argv[2] || "";
let apps;
try {
  apps = JSON.parse(input);
} catch (error) {
  console.error(input);
  console.error("Could not parse `clerk apps list --json` output as JSON.");
  process.exit(2);
}
const aliases = {
  dev: "development",
  development: "development",
  prod: "production",
  production: "production",
};
const requestedEnv = aliases[requested];
const matches = [];
for (const app of apps) {
  for (const instance of app.instances || []) {
    const isMatch = requested
      ? (requestedEnv ? instance.environment_type === requestedEnv : instance.instance_id === requested)
      : instance.environment_type === "development";
    if (isMatch) {
      matches.push({
        appId: app.application_id,
        appName: app.name || app.application_id,
        instanceId: instance.instance_id,
        environment: instance.environment_type,
      });
    }
  }
}
if (matches.length === 0) {
  console.error(requested
    ? `No Clerk instance matched --instance ${requested}.`
    : "No development instance found.");
  process.exit(3);
}
if (matches.length > 1) {
  console.error(requested
    ? `More than one ${requested} instance matched. Pass a full instance id.`
    : "More than one development instance was found. Pass --instance <instance_id>.");
  for (const match of matches) {
    console.error(`  ${match.instanceId} (${match.environment}) in ${match.appName} [${match.appId}]`);
  }
  process.exit(4);
}
process.stdout.write(JSON.stringify(matches[0]));
NODE
}

find_oauth_app_id() {
  local list_json="$1"
  OAUTH_APPS_JSON="$list_json" node - "$CLIENT_ID" "$NAME" <<'NODE'
const input = process.env.OAUTH_APPS_JSON || "";
const clientId = process.argv[2] || "";
const name = process.argv[3] || "";
let parsed;
try {
  parsed = JSON.parse(input);
} catch (error) {
  console.error(input);
  console.error("Could not parse OAuth Application list response as JSON.");
  process.exit(2);
}
const apps = Array.isArray(parsed) ? parsed : (parsed.data || []);
const matches = apps.filter((app) => clientId ? app.client_id === clientId : app.name === name);
if (matches.length === 0) {
  console.error(clientId
    ? `No OAuth Application matched client_id ${clientId}.`
    : `No OAuth Application matched name "${name}".`);
  process.exit(3);
}
if (matches.length > 1) {
  console.error(clientId
    ? `Multiple OAuth Applications matched client_id ${clientId}.`
    : `Multiple OAuth Applications matched name "${name}". Re-run with --client-id.`);
  for (const app of matches) {
    console.error(`  id=${app.id} client_id=${app.client_id} name=${app.name}`);
  }
  process.exit(4);
}
const app = matches[0];
if (!app.id) {
  console.error(JSON.stringify(app, null, 2));
  console.error("Matched OAuth Application does not include an id.");
  process.exit(5);
}
console.log(app.id);
NODE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --client-id)
      [ "$#" -ge 2 ] || die "--client-id requires a value"
      CLIENT_ID="$2"
      shift 2
      ;;
    --name)
      [ "$#" -ge 2 ] || die "--name requires a value"
      NAME="$2"
      shift 2
      ;;
    --instance)
      [ "$#" -ge 2 ] || die "--instance requires a value"
      INSTANCE="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown flag: $1"
      ;;
  esac
done

if [ "$APPLY" -ne 1 ]; then
  printf 'DRY RUN: no Clerk backend mutation will be executed.\n\n'
  printf 'Would verify Hunter CLI auth:\n  %s\n\n' "$(print_clerk_cmd whoami)"
  printf 'Would resolve target application/instance:\n  %s\n\n' "$(print_clerk_cmd apps list --json)"
  if [ -n "$INSTANCE" ]; then
    printf 'Requested instance: %s\n\n' "$INSTANCE"
  else
    printf 'No --instance provided; would select the single development instance or ask for --instance if ambiguous.\n\n'
  fi
  if [ -n "$CLIENT_ID" ]; then
    printf 'Would lookup OAuth Application by client_id: %s\n' "$CLIENT_ID"
    printf 'Would run:\n  %s\n\n' "$(print_clerk_cmd api /oauth_applications --app "<resolved-app-id>" --instance "<resolved-instance-id>")"
  else
    printf 'Would lookup OAuth Application by name: %s\n' "$NAME"
    printf 'Would run:\n  %s\n\n' "$(print_clerk_cmd api "/oauth_applications?limit=100&name_query=$(urlencode "$NAME")" --app "<resolved-app-id>" --instance "<resolved-instance-id>")"
  fi
  printf 'Would delete the resolved OAuth Application:\n  %s\n' "$(print_clerk_cmd api /oauth_applications/"<resolved-oauth-application-id>" --app "<resolved-app-id>" --instance "<resolved-instance-id>" -X DELETE --yes)"
  exit 0
fi

require_apply_prereqs

if ! WHOAMI="$(clerk_cmd whoami 2>&1)"; then
  printf '%s\n' "$WHOAMI" >&2
  die "Hunter's Clerk CLI is not authenticated; run `bun run --cwd $CLERK_CLI_CORE src/cli.ts auth login`"
fi

TARGET_JSON="$(resolve_target)"
APP_ID="$(node -e 'const v=JSON.parse(process.argv[1]); console.log(v.appId)' "$TARGET_JSON")"
INSTANCE_ID="$(node -e 'const v=JSON.parse(process.argv[1]); console.log(v.instanceId)' "$TARGET_JSON")"

if [ -n "$CLIENT_ID" ]; then
  LIST_PATH="/oauth_applications?limit=100"
else
  LIST_PATH="/oauth_applications?limit=100&name_query=$(urlencode "$NAME")"
fi

if ! LIST_RESPONSE="$(clerk_cmd api "$LIST_PATH" --app "$APP_ID" --instance "$INSTANCE_ID" 2>&1)"; then
  printf 'Failed to list OAuth Applications. Response body/output:\n%s\n' "$LIST_RESPONSE" >&2
  exit 1
fi

OAUTH_APP_ID="$(find_oauth_app_id "$LIST_RESPONSE")"

printf 'Deleting OAuth Application %s on instance %s...\n' "$OAUTH_APP_ID" "$INSTANCE_ID" >&2
if ! DELETE_RESPONSE="$(clerk_cmd api "/oauth_applications/$OAUTH_APP_ID" --app "$APP_ID" --instance "$INSTANCE_ID" -X DELETE --yes 2>&1)"; then
  printf 'Failed to delete OAuth Application. Response body/output:\n%s\n' "$DELETE_RESPONSE" >&2
  exit 1
fi

printf 'Deleted OAuth Application %s.\n' "$OAUTH_APP_ID"
if [ -n "$DELETE_RESPONSE" ]; then
  printf '%s\n' "$DELETE_RESPONSE"
fi
