#!/usr/bin/env bash
# A wizard: walks a human through the steps only they can take.
#
# Everything above the STAGES marker is the shared library and is identical in
# every wizard the `wizard` skill generates. Do not hand-edit it: a reviewer
# reads the stages and trusts the machinery, which only works while the
# machinery is the same everywhere.
#
# Author your stages below the marker, set TOTAL_STAGES, and delete the example.
set -uo pipefail

TOTAL_STAGES=6          # set this to the number of stages you write
CURRENT_STAGE=0
ENV_FILE="${ENV_FILE:-.env}"
CAPTURED=()             # "KEY=where it went", for the closing summary

# ── Presentation ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
else
  BOLD=''; DIM=''; RESET=''; BLUE=''; GREEN=''; YELLOW=''; RED=''
fi

_clear() { [ -t 1 ] && printf '\033[2J\033[H' || true; }

banner() {
  printf '%s%s%s\n' "$BOLD" "$1" "$RESET"
  printf '%s%s%s\n\n' "$DIM" "$(printf '%0.s─' $(seq 1 ${#1}))" "$RESET"
}

# One screen per stage. Anything the human needs must fit on it.
stage() {
  CURRENT_STAGE=$((CURRENT_STAGE + 1))
  _clear
  printf '%s[%d/%d]%s %s%s%s\n\n' \
    "$DIM" "$CURRENT_STAGE" "$TOTAL_STAGES" "$RESET" "$BOLD" "$1" "$RESET"
}

say()  { printf '  %s\n' "$1"; }
step() { printf '  %s>%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s! %s%s\n' "$YELLOW" "$1" "$RESET"; }
ok()   { printf '  %s+%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { printf '  %sx %s%s\n' "$RED" "$1" "$RESET"; }

# ── Browser ─────────────────────────────────────────────────────────────────
# Always open the URL before asking for the value it produces.
open_url() {
  local url="$1"
  step "Opening: $url"
  if   command -v open        >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
  elif command -v wslview     >/dev/null 2>&1; then wslview "$url" >/dev/null 2>&1 &
  elif command -v xdg-open    >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile Start-Process "$url" >/dev/null 2>&1 &
  else
    note "could not open a browser here, visit it by hand"
  fi
  sleep 1
}

# ── Gates ───────────────────────────────────────────────────────────────────
pause() { printf '\n  %sPress enter when done.%s ' "$DIM" "$RESET"; read -r _; }

# Use before anything irreversible. Name what is about to happen: a bare
# "Continue?" gets a reflexive yes.
confirm() {
  local ans
  printf '\n  %s%s%s [y/N] ' "$YELLOW" "$1" "$RESET"
  read -r ans
  case "$ans" in [yY]|[yY][eE][sS]) return 0 ;; *) fail "stopped"; exit 1 ;; esac
}

# ── Capture ─────────────────────────────────────────────────────────────────
# A value already in .env is offered as the default, so re-running the wizard
# to fix one stage does not mean retyping every earlier one.
_existing() {
  [ -f "$ENV_FILE" ] || return 1
  local line; line=$(grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null) || return 1
  printf '%s' "${line#*=}" | sed 's/^"//; s/"$//'
}

ask() {
  local key="$1" prompt="$2" cur val
  cur=$(_existing "$key") || cur=''
  if [ -n "$cur" ]; then
    printf '\n  %s [%s]: ' "$prompt" "$cur"
  else
    printf '\n  %s: ' "$prompt"
  fi
  read -r val
  [ -z "$val" ] && val="$cur"
  [ -z "$val" ] && { fail "$key is required"; exit 1; }
  printf -v "$key" '%s' "$val"
  export "${key?}"
}

# Never echoes. Use for anything that must not survive in scrollback.
ask_secret() {
  local key="$1" prompt="$2" cur val
  cur=$(_existing "$key") || cur=''
  if [ -n "$cur" ]; then
    printf '\n  %s [keep existing]: ' "$prompt"
  else
    printf '\n  %s: ' "$prompt"
  fi
  read -rs val; printf '\n'
  [ -z "$val" ] && val="$cur"
  [ -z "$val" ] && { fail "$key is required"; exit 1; }
  printf -v "$key" '%s' "$val"
  export "${key?}"
}

# ── Persistence ─────────────────────────────────────────────────────────────
# Idempotent: re-running replaces the line rather than appending a second one,
# which is the bug that makes a half-finished wizard run unrecoverable.
write_env() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  if grep -q "^$key=" "$ENV_FILE" 2>/dev/null; then
    local tmp; tmp=$(mktemp)
    grep -v "^$key=" "$ENV_FILE" > "$tmp" && mv "$tmp" "$ENV_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  CAPTURED+=("$key -> $ENV_FILE")
  ok "$key written to $ENV_FILE"
}

# The name must match a secrets.* reference in CI exactly. CI reports a
# mismatched name as an empty string, never as an error.
set_secret() {
  local key="$1" val="$2"
  command -v gh >/dev/null 2>&1 || { warn "gh not installed, skipping secret $key"; return 0; }
  if printf '%s' "$val" | gh secret set "$key" --body-file - 2>/dev/null; then
    CAPTURED+=("$key -> GitHub secret")
    ok "$key set as a GitHub secret"
  else
    fail "could not set GitHub secret $key (is gh authenticated for this repo?)"
  fi
}

set_var() {
  local key="$1" val="$2"
  command -v gh >/dev/null 2>&1 || { warn "gh not installed, skipping variable $key"; return 0; }
  if gh variable set "$key" --body "$val" >/dev/null 2>&1; then
    CAPTURED+=("$key -> GitHub variable")
    ok "$key set as a GitHub variable"
  else
    fail "could not set GitHub variable $key"
  fi
}

# ── Close ───────────────────────────────────────────────────────────────────
finish() {
  _clear
  banner "Done"
  if [ ${#CAPTURED[@]} -gt 0 ]; then
    say "Captured:"
    for entry in "${CAPTURED[@]}"; do note "  $entry"; done
    printf '\n'
  fi
  [ $# -gt 0 ] && { say "$1"; printf '\n'; }
  if [ "$CURRENT_STAGE" -ne "$TOTAL_STAGES" ]; then
    warn "ran $CURRENT_STAGE of $TOTAL_STAGES stages: TOTAL_STAGES is wrong, or a stage was skipped"
  fi
}

# ---- STAGES ----------------------------------------------------------------
# Why this is a wizard and not a script the agent ran: applying it needs
# Cloudflare credentials and it changes response headers for every site that
# links cdn.neorgon.org. That is 44 sites. A person should be watching.
#
# What it does NOT do: it does not put the Worker (src/index.js) in the request
# path. cdn.neorgon.org stays bound directly to the R2 bucket exactly as it is
# now. A bucket CORS policy is honoured by that binding, which is why this is
# the low-risk route: no routing change, no new code in front of the fleet.

BUCKET="neorgon-cdn-prod"
HOST="https://cdn.neorgon.org"
PROBE="$HOST/v1.0.0/styles/base.css"
TEST_ORIGIN="https://mosaic.neorgon.com"
OUT="${TMPDIR:-/tmp}/r2-cors-$$"
mkdir -p "$OUT"

_clear
banner "R2 CORS for cdn.neorgon.org"
say "cdn.neorgon.org serves the fleet's design tokens (base.css, season.css)"
say "and the shared logo. It returns no Access-Control-Allow-Origin today, so"
say "a browser can fetch those files as a stylesheet but NOT with fetch(),"
say "and a service worker cannot cache them as anything but an opaque blob."
printf '\n'
say "This wizard adds a bucket CORS policy so it does. Six stages."
note "Nothing is changed before stage 4, and stage 4 asks first."
printf '\n'
pause

stage "Confirm the gap is still real"
say "Measuring the live response before touching anything."
printf '\n'
if curl -sI -H "Origin: $TEST_ORIGIN" "$PROBE" > "$OUT/before.headers" 2>/dev/null; then
  if grep -qi '^access-control-allow-origin' "$OUT/before.headers"; then
    ok "It already sends Access-Control-Allow-Origin:"
    grep -i '^access-control-allow-origin' "$OUT/before.headers" | sed 's/^/    /'
    printf '\n'
    warn "Someone has already done this. You can stop here unless you are changing the policy."
  else
    ok "Confirmed: no Access-Control-Allow-Origin in the response."
    note "Saved the full headers to $OUT/before.headers"
  fi
else
  fail "Could not reach $PROBE. Check the network before continuing."
fi
printf '\n'
pause

stage "Back up whatever policy exists now"
say "R2 shows the current policy in the same place you are about to edit."
open_url "https://dash.cloudflare.com/"
step "R2 Object Storage -> $BUCKET -> Settings -> CORS Policy"
printf '\n'
say "If a policy is already there, copy the whole JSON block and save it."
say "Paste it into a file now, or take a screenshot. If the section is empty,"
say "there is nothing to back up and the rollback is 'delete the policy'."
printf '\n'
note "Recording that you checked, so the rollback note at the end is honest."
ask HAD_POLICY "Was there an existing policy? (yes/no)"
printf '%s\n' "$HAD_POLICY" > "$OUT/had-policy.txt"
pause

stage "Review the policy you are about to apply"
cat > "$OUT/cors.json" <<'JSON'
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["Range"],
    "ExposeHeaders": ["ETag", "Content-Length", "Content-Type"],
    "MaxAgeSeconds": 86400
  }
]
JSON
say "Written to $OUT/cors.json:"
printf '\n'
sed 's/^/    /' "$OUT/cors.json"
printf '\n'
say "Why each field:"
note "AllowedOrigins \"*\"  the assets are public and carry no credentials, and"
note "                     the fleet spans *.neorgon.com plus localhost dev."
note "                     This is what src/index.js already sets when it runs."
note "GET, HEAD            read-only. Uploads go through the S3 API, not here."
note "Range                the CDN advertises accept-ranges: bytes."
note "MaxAgeSeconds 86400  the documented maximum; browsers may cap it at 2h."
printf '\n'
warn "Shape matters: the dashboard takes THIS array form (AllowedOrigins)."
warn "The wrangler --file docs show a different {\"rules\":[{\"allowed\":...}]}"
warn "shape. Pasting the wrong one into the wrong place is rejected."
printf '\n'
pause

stage "Apply it"
say "Back to the tab from stage 2:"
open_url "https://dash.cloudflare.com/"
step "R2 Object Storage -> $BUCKET -> Settings -> CORS Policy -> Edit"
step "Replace the contents with the JSON from stage 3, then save"
printf '\n'
note "CLI alternative, if you would rather:"
note "  npx wrangler r2 bucket cors set $BUCKET --file $OUT/cors.json"
note "It needs a working wrangler. On this machine npx wrangler currently dies"
note "on a mis-installed workerd binary in the monorepo root node_modules, so"
note "run it from inside this repo after a clean npm install, or use the dashboard."
printf '\n'
confirm "apply a CORS policy to $BUCKET, changing response headers for 44 sites"
pause

stage "Verify from the command line"
say "Cloudflare only returns CORS headers when the request carries an Origin,"
say "so a bare curl -I will look unchanged even on success."
printf '\n'
say "Probing $PROBE with Origin: $TEST_ORIGIN"
printf '\n'
sleep 2
if curl -sI -H "Origin: $TEST_ORIGIN" "$PROBE" > "$OUT/after.headers" 2>/dev/null; then
  if grep -qi '^access-control-allow-origin' "$OUT/after.headers"; then
    ok "Access-Control-Allow-Origin is present:"
    grep -i '^access-control-allow-origin\|^access-control-expose' "$OUT/after.headers" | sed 's/^/    /'
  else
    fail "Still no Access-Control-Allow-Origin."
    say "Give the edge a minute and re-run this stage, and check that the"
    say "policy saved. If it still fails, the policy did not apply to the"
    say "custom-domain binding: say so rather than editing the Worker."
  fi
else
  fail "Could not reach $PROBE."
fi
printf '\n'
pause

stage "Verify in a browser, which is what actually matters"
say "curl proves the header. Only a browser proves the fetch succeeds."
open_url "$TEST_ORIGIN/"
step "Open DevTools -> Console on that page and paste:"
printf '\n'
say "    await fetch('$PROBE', {mode:'cors'}).then(r => r.type)"
printf '\n'
say "Expected: the string \"cors\"."
say "Before this change it threw TypeError: Failed to fetch."
printf '\n'
note "If that returns \"cors\", a service worker can now cache the fleet's"
note "design tokens as a real response instead of an opaque one."
printf '\n'
pause

finish "CORS is on the bucket. To roll back: same screen, and either restore the
  policy you saved in stage 2 or delete the policy outright if there was none.
  Rolling back only removes the header; it cannot break a site that renders the
  stylesheet through a <link> tag, which is every site today."
