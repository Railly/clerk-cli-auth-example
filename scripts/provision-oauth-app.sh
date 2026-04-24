#!/usr/bin/env bash
set -euo pipefail

DEFAULT_NAME="cli-auth-local-test"
DEFAULT_REDIRECT_URI="http://127.0.0.1:0/callback"
DEFAULT_SCOPES="profile email openid offline_access"
SDK_REPO="/Users/raillyhugo/Programming/railly/clerk-cli-auth"
CLERK_CLI_REPO="${CLERK_CLI_REPO:-/Users/raillyhugo/Clerk/cli}"
CLERK_CLI_CORE="$CLERK_CLI_REPO/packages/cli-core"

NAME="$DEFAULT_NAME"
REDIRECT_URI="$DEFAULT_REDIRECT_URI"
INSTANCE=""
APPLY=0

usage() {
  cat <<'USAGE'
Usage: scripts/provision-oauth-app.sh [flags]

Flags:
  --name <app name>       OAuth Application name. Default: cli-auth-local-test
  --redirect-uri <uri>    Redirect URI. Default: http://127.0.0.1:0/callback
  --instance <id>         Optional instance id or environment alias. If omitted,
                          the single development instance from `clerk apps list`
                          is selected.
  --apply                 Create the OAuth Application. Default is dry-run.
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
  bun run --cwd "$CLERK_CLI_CORE" src/cli.ts --mode agent "$@"
}

print_clerk_cmd() {
  shell_join bun run --cwd "$CLERK_CLI_CORE" src/cli.ts --mode agent "$@"
}

require_apply_prereqs() {
  command -v bun >/dev/null 2>&1 || die "bun is required"
  command -v node >/dev/null 2>&1 || die "node is required for JSON parsing"
  [ -d "$SDK_REPO" ] || die "SDK repo not found: $SDK_REPO"
  [ -d "$CLERK_CLI_CORE" ] || die "Hunter's Clerk CLI repo not found: $CLERK_CLI_CORE"
}

json_payload() {
  node - "$NAME" "$REDIRECT_URI" "$DEFAULT_SCOPES" <<'NODE'
const [name, redirectUri, scopes] = process.argv.slice(2);
process.stdout.write(JSON.stringify({
  name,
  redirect_uris: [redirectUri],
  public: true,
  pkce_required: true,
  scopes,
}));
NODE
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

extract_result() {
  node - <<'NODE'
const input = process.env.RESPONSE_JSON || "";
let app;
try {
  app = JSON.parse(input);
} catch (error) {
  console.error(input);
  console.error("Could not parse OAuth Application create response as JSON.");
  process.exit(2);
}
const clientId = app.client_id;
let issuer = app.issuer;
if (!issuer && app.discovery_url) {
  issuer = String(app.discovery_url).replace(/\/\.well-known\/openid-configuration\/?$/, "");
}
if (!issuer && app.authorize_url) {
  const url = new URL(app.authorize_url);
  issuer = `${url.protocol}//${url.host}`;
}
if (!issuer && app.token_fetch_url) {
  const url = new URL(app.token_fetch_url);
  issuer = `${url.protocol}//${url.host}`;
}
if (!clientId || !issuer) {
  console.error(JSON.stringify(app, null, 2));
  console.error("Create response did not include enough data to derive client_id and issuer.");
  process.exit(3);
}
console.log(`client_id: ${clientId}`);
console.log(`issuer: ${issuer}`);
console.log("");
console.log(`export CLERK_OAUTH_CLIENT_ID=${JSON.stringify(clientId)}`);
console.log(`export CLERK_ISSUER=${JSON.stringify(issuer)}`);
NODE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || die "--name requires a value"
      NAME="$2"
      shift 2
      ;;
    --redirect-uri)
      [ "$#" -ge 2 ] || die "--redirect-uri requires a value"
      REDIRECT_URI="$2"
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

PAYLOAD="$(json_payload)"

if [ "$APPLY" -ne 1 ]; then
  printf 'DRY RUN: no Clerk backend mutation will be executed.\n\n'
  printf 'Would verify Hunter CLI auth:\n  %s\n\n' "$(print_clerk_cmd whoami)"
  printf 'Would resolve target application/instance:\n  %s\n\n' "$(print_clerk_cmd apps list --json)"
  if [ -n "$INSTANCE" ]; then
    printf 'Requested instance: %s\n\n' "$INSTANCE"
  else
    printf 'No --instance provided; would select the single development instance or ask for --instance if ambiguous.\n\n'
  fi
  printf 'Would create OAuth Application with payload:\n%s\n\n' "$PAYLOAD"
  printf 'Would run:\n  %s\n' "$(print_clerk_cmd api /oauth_applications --app "<resolved-app-id>" --instance "<resolved-instance-id>" -X POST -d "$PAYLOAD" --yes)"
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

printf 'Creating OAuth Application "%s" on instance %s...\n' "$NAME" "$INSTANCE_ID" >&2
if ! RESPONSE="$(clerk_cmd api /oauth_applications --app "$APP_ID" --instance "$INSTANCE_ID" -X POST -d "$PAYLOAD" --yes 2>&1)"; then
  printf 'Failed to create OAuth Application. Response body/output:\n%s\n' "$RESPONSE" >&2
  exit 1
fi

RESPONSE_JSON="$RESPONSE" extract_result
