#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUBMISSION_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SYSREPORT="$SUBMISSION_DIR/scripts/sysreport.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf -- "$TEST_TMP"' EXIT

failures=0

assert_contains() {
  local output=$1
  local expected=$2
  local label=$3
  if [[ "$output" != *"$expected"* ]]; then
    printf 'FAIL: %s (missing: %s)\n' "$label" "$expected" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: %s\n' "$label"
  fi
}

assert_not_contains() {
  local output=$1
  local unexpected=$2
  local label=$3
  if [[ "$output" == *"$unexpected"* ]]; then
    printf 'FAIL: %s (unexpected: %s)\n' "$label" "$unexpected" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: %s\n' "$label"
  fi
}

assert_count() {
  local output=$1
  local expected=$2
  local count
  local label=$3
  count=$(grep -Fo "$expected" <<<"$output" | wc -l)
  count=${count//[[:space:]]/}
  if [[ "$count" -ne 1 ]]; then
    printf 'FAIL: %s (expected 1, got %s occurrences)\n' "$label" "$count" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: %s\n' "$label"
  fi
}

NOW=$(date '+%s')
ACTIVE_MONTH=$(date -d "@$NOW" '+%b')
ACTIVE_DAY=$(date -d "@$NOW" '+%-d')
ACTIVE_TIME=$(date -d "@$NOW" '+%H:%M:%S')
OLD_MONTH=$(date -d "@$((NOW - 90000))" '+%b')
OLD_DAY=$(date -d "@$((NOW - 90000))" '+%-d')
OLD_TIME=$(date -d "@$((NOW - 90000))" '+%H:%M:%S')
ROTATED_MONTH=$(date -d "@$((NOW - 43200))" '+%b')
ROTATED_DAY=$(date -d "@$((NOW - 43200))" '+%-d')
ROTATED_TIME=$(date -d "@$((NOW - 43200))" '+%H:%M:%S')

mkdir -p "$TEST_TMP/active"
cat > "$TEST_TMP/active/auth.log" <<EOF
$ACTIVE_MONTH $ACTIVE_DAY $ACTIVE_TIME localhost sshd[1111]: Failed password for invalid user alice from 192.0.2.10 port 2222 ssh2
EOF
AUTH_LOG_DIR="$TEST_TMP/active" JOURNALCTL_BIN=/definitely/missing/journalctl SYSTEMCTL_BIN=/definitely/missing/systemctl \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/active.out"
active_output=$(<"$TEST_TMP/active.out")
assert_contains "$active_output" "Failed password for invalid user alice" "failed attempt in active auth.log"

mkdir -p "$TEST_TMP/rotated"
cat > "$TEST_TMP/rotated/auth.log.1" <<EOF
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sshd[2222]: Failed password for bob from 192.0.2.11 port 2200 ssh2
EOF
AUTH_LOG_DIR="$TEST_TMP/rotated" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/rotated.out"
rotated_output=$(<"$TEST_TMP/rotated.out")
assert_contains "$rotated_output" "Failed password for bob" "failed attempt in rotated auth.log.1"

mkdir -p "$TEST_TMP/old"
cat > "$TEST_TMP/old/auth.log" <<EOF
$OLD_MONTH $OLD_DAY $OLD_TIME host sshd[3333]: Failed password for olduser from 192.0.2.12 port 2201 ssh2
EOF
AUTH_LOG_DIR="$TEST_TMP/old" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/old.out"
old_output=$(<"$TEST_TMP/old.out")
assert_not_contains "$old_output" "Failed password for olduser" "record older than 24 hours is excluded"

mkdir -p "$TEST_TMP/missing"
AUTH_LOG_DIR="$TEST_TMP/missing" JOURNALCTL_BIN=/definitely/missing/journalctl SYSTEMCTL_BIN=/definitely/missing/systemctl \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/missing.out"
missing_output=$(<"$TEST_TMP/missing.out")
assert_contains "$missing_output" "SSH authentication logs and journal data are unavailable" "missing logs are handled"

mkdir -p "$TEST_TMP/empty"
: > "$TEST_TMP/empty/auth.log"
AUTH_LOG_DIR="$TEST_TMP/empty" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/empty.out"
empty_output=$(<"$TEST_TMP/empty.out")
assert_contains "$empty_output" "No failed SSH login records found" "empty auth.log is handled"

mkdir -p "$TEST_TMP/malformed"
cat > "$TEST_TMP/malformed/auth.log" <<EOF
this is not a valid log line
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sudo: authentication failure; logname=user
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sshd[4444]: Accepted publickey for user
EOF
AUTH_LOG_DIR="$TEST_TMP/malformed" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/malformed.out"
malformed_output=$(<"$TEST_TMP/malformed.out")
assert_not_contains "$malformed_output" "authentication failure" "unrelated sudo failure is excluded"
assert_not_contains "$malformed_output" "Accepted publickey" "malformed/unrelated SSH record is excluded"

mkdir -p "$TEST_TMP/compressed"
cat > "$TEST_TMP/compressed/auth.log.2" <<EOF
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sshd[5555]: Maximum authentication attempts exceeded for eve from 192.0.2.13 port 2202 ssh2
EOF
gzip -c "$TEST_TMP/compressed/auth.log.2" > "$TEST_TMP/compressed/auth.log.2.gz"
rm "$TEST_TMP/compressed/auth.log.2"
AUTH_LOG_DIR="$TEST_TMP/compressed" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/compressed.out"
compressed_output=$(<"$TEST_TMP/compressed.out")
assert_contains "$compressed_output" "Maximum authentication attempts exceeded for eve" "compressed rotated auth.log.2.gz is handled"

mkdir -p "$TEST_TMP/deduplicated"
cat > "$TEST_TMP/deduplicated/auth.log" <<EOF
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sshd[6666]: Failed password for carol from 192.0.2.14 port 2203 ssh2
EOF
cat > "$TEST_TMP/deduplicated/auth.log.1" <<EOF
$ROTATED_MONTH $ROTATED_DAY $ROTATED_TIME host sshd[6666]: Failed password for carol from 192.0.2.14 port 2203 ssh2
EOF
AUTH_LOG_DIR="$TEST_TMP/deduplicated" JOURNALCTL_BIN=/bin/false SYSTEMCTL_BIN=/bin/false \
  bash -c 'source "$1"; report_ssh_failures' _ "$SYSREPORT" > "$TEST_TMP/deduplicated.out"
deduplicated_output=$(<"$TEST_TMP/deduplicated.out")
assert_count "$deduplicated_output" "Failed password for carol" "duplicate records across auth.log and auth.log.1 are not printed twice"

if ((failures > 0)); then
  printf '%d test(s) failed.\n' "$failures" >&2
  exit 1
fi

printf 'All SSH authentication log tests passed.\n'
