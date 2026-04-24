#!/usr/bin/env bash
set -euo pipefail

SDK_REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_REPO="${DEMO_REPO:-$SDK_REPO/../clerk-cli-auth-demo}"
CLERK_CLI_REPO="${CLERK_CLI_REPO:-}"
CLERK_CLI_CORE="${CLERK_CLI_REPO:+$CLERK_CLI_REPO/packages/cli-core}"
ENV_FILE="$HOME/.clerk-cli-auth-demo.env"
CHECK_ONLY=0

usage() {
  cat <<'USAGE'
Usage: scripts/local-test.sh [--check]

Checks local prerequisites and prints the manual end-to-end demo steps.

Flags:
  --check     Validate prerequisites only. Do not prompt or print manual run steps.
  -h, --help  Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown flag: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

clerk_cmd() {
  if command -v clerk >/dev/null 2>&1; then
    clerk --mode agent "$@"
  else
    bun run --cwd "$CLERK_CLI_CORE" src/cli.ts --mode agent "$@"
  fi
}

ok() {
  printf '[ok]   %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1"
}

FAILURES=0

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$label"
  else
    fail "$label"
    FAILURES=$((FAILURES + 1))
  fi
}

check_dir() {
  local dir="$1"
  local label="$2"
  if [ -d "$dir" ]; then
    ok "$label"
  else
    fail "$label ($dir)"
    FAILURES=$((FAILURES + 1))
  fi
}

check_file() {
  local file="$1"
  local label="$2"
  if [ -f "$file" ]; then
    ok "$label"
  else
    fail "$label ($file)"
    FAILURES=$((FAILURES + 1))
  fi
}

printf 'Checking local integration test prerequisites...\n\n'

check_cmd bun "bun is installed"
check_cmd node "node is installed"
check_dir "$SDK_REPO" "SDK repo exists"
check_dir "$DEMO_REPO" "demo consumer repo exists"

if command -v clerk >/dev/null 2>&1; then
  ok "Clerk CLI is available (clerk on PATH)"
elif [ -n "$CLERK_CLI_CORE" ] && [ -d "$CLERK_CLI_CORE" ]; then
  ok "Clerk CLI is available (source at \$CLERK_CLI_REPO)"
else
  fail "Clerk CLI is available"
  printf '       install clerk or set CLERK_CLI_REPO to a Clerk CLI source checkout\n'
  FAILURES=$((FAILURES + 1))
fi

check_file "$SDK_REPO/dist/index.mjs" "SDK build exists: dist/index.mjs"

if command -v clerk >/dev/null 2>&1 || { command -v bun >/dev/null 2>&1 && [ -n "$CLERK_CLI_CORE" ] && [ -d "$CLERK_CLI_CORE" ]; }; then
  if WHOAMI="$(clerk_cmd whoami 2>&1)"; then
    ok "Clerk CLI is authenticated ($WHOAMI)"
  else
    fail "Clerk CLI is authenticated"
    printf '       %s\n' "$WHOAMI"
    FAILURES=$((FAILURES + 1))
  fi
else
  fail "Clerk CLI auth check could run"
  FAILURES=$((FAILURES + 1))
fi

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  ok "demo env file exists: $ENV_FILE"
  if [ -n "${CLERK_OAUTH_CLIENT_ID:-}" ]; then
    ok "CLERK_OAUTH_CLIENT_ID is set"
  else
    fail "CLERK_OAUTH_CLIENT_ID is set in $ENV_FILE"
    FAILURES=$((FAILURES + 1))
  fi
  if [ -n "${CLERK_ISSUER:-}" ]; then
    ok "CLERK_ISSUER is set"
  else
    fail "CLERK_ISSUER is set in $ENV_FILE"
    FAILURES=$((FAILURES + 1))
  fi
else
  fail "demo env file exists: $ENV_FILE"
  FAILURES=$((FAILURES + 1))
fi

printf '\n'

if [ "$FAILURES" -gt 0 ]; then
  printf 'Prereq check failed with %s issue(s).\n' "$FAILURES"
  if [ "$CHECK_ONLY" -eq 1 ]; then
    exit 1
  fi
  if [ ! -f "$ENV_FILE" ]; then
    cat <<EOF
Create a test OAuth Application first, then save the printed exports:

  cd $SDK_REPO
  scripts/provision-oauth-app.sh --apply

Suggested env file command:

cat > $ENV_FILE <<'ENV'
export CLERK_OAUTH_CLIENT_ID="<client_id from provision output>"
export CLERK_ISSUER="<issuer from provision output>"
ENV
EOF
  fi
  exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  printf 'All required prereqs are present.\n'
  exit 0
fi

cat <<EOF
Environment loaded from:
  $ENV_FILE

Manual demo steps:

Terminal 1:
  cd ../clerk-cli-auth-demo
  bun run demo-cli login

Browser:
  Approve the OAuth consent prompt.

Expected terminal output:
  Logged in as <email>

Then run:
  bun run demo-cli whoami

Expected:
  The same user email.

Then run:
  bun run demo-cli logout

Expected:
  Logged out.
EOF
