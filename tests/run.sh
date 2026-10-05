#!/usr/bin/env bash
# Snapshot tests for iplense.sh. A stub curl (tests/stub/curl) answers from tests/fixtures, so nothing reaches the network.
# Run: bash tests/run.sh          Refresh snapshots after an intended change: UPDATE=1 bash tests/run.sh

cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
# Scratch files live in tests/.work (ignored by Git) and are overwritten on each run.
mkdir -p tests/.work
STUB_LOG=$ROOT/tests/.work/curl.log
OUT_FILE=$ROOT/tests/.work/saved.txt
: >"$OUT_FILE"
export PATH="$ROOT/tests/stub:$PATH" STUB_LOG
unset NO_COLOR LC_ALL LC_MESSAGES LC_CTYPE
failed=0 passed=0

# The script is loaded without its last line (main "$@") so the port 25 connection can be answered by STUB_SMTP
# ("220", "silent" or anything else for a refused connection); every other request goes to the stub curl.
# shellcheck disable=SC2016 # expanded by the inner bash, not here.
HARNESS='eval "$(sed "\$d" "$0")"
smtp_greeting() { case ${STUB_SMTP-} in 220) printf "220 mx.example ESMTP" ;; silent) return 2 ;; *) return 1 ;; esac; }
main "$@"'

# run NAME "ENV=VALUE ..." ARGS... : runs the script with that environment, compares stdout+stderr and the exit code.
# Platform pages default to the "available" fixtures and port 25 to a greeting.
run() {
	local name=$1 envs=$2 actual expected
	shift 2
	: >"$STUB_LOG"
	# shellcheck disable=SC2086
	actual=$(env -u STUB_V4 -u STUB_V6 COLUMNS=80 LANG=en_US.UTF-8 STUB_LOCAL=available STUB_SMTP=220 $envs \
		bash -c "$HARNESS" "$ROOT/iplense.sh" "$@" 2>&1; printf '\n[exit %s]' "$?")
	if [ "${UPDATE-}" = 1 ]; then
		printf '%s\n' "$actual" >"tests/snapshots/$name.txt"
	fi
	expected=$(cat "tests/snapshots/$name.txt" 2>/dev/null)
	if [ "$actual" = "$expected" ]; then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		printf 'FAIL %s\n' "$name"
		diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | head -20
	fi
	LAST=$actual
}

# check NAME COMMAND... : passes when the command succeeds.
check() {
	local name=$1
	shift
	if "$@"; then passed=$((passed + 1)); else failed=$((failed + 1)); printf 'FAIL %s\n' "$name"; fi
}

exits_with() { [ "$(exit_code)" = "$1" ]; }
# Requests to the self-check only (the local checks log their own).
one_request() { [ "$(grep 'iplense.cc' "$STUB_LOG" | grep -c -- "^-$1 ")" = 1 ] && ! grep 'iplense.cc' "$STUB_LOG" | grep -q -- "^-$2 "; }
logged() { grep -q -- "$1" "$STUB_LOG"; }
no_controls() { ! has_controls "$LAST"; }
saved_matches() { [ "$(cat "$OUT_FILE")" = "$(printf '%s\n' "$LAST" | sed '$d' | sed '$d' | sed '$d')" ]; }
saved_plain() { ! LC_ALL=C grep -q "$(printf '\033')" "$OUT_FILE"; }

exit_code() {
	local tail=${LAST##*\[exit }
	printf '%s' "${tail%]}"
}

has_controls() {
	printf '%s' "$1" | LC_ALL=C grep -q "$(printf '[\001-\011\013-\037\177]')" || printf '%s' "$1" | LC_ALL=C grep -q "$(printf '\302[\200-\237]')"
}

last_line() { [ "$(tail -n 1 "$ROOT/iplense.sh")" = 'main "$@"' ]; }
check "the script ends with main \"\$@\" (the harness drops that line)" last_line

for lang in en zh; do
	for cols in 80 120; do
		run "$lang-$cols-dual" "LANG=${lang}_US.UTF-8 COLUMNS=$cols STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200"
	done
	run "$lang-80-v4-only" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200"
	run "$lang-80-v6-only" "LANG=${lang}_US.UTF-8 STUB_V6=full-v6.kv:200"
	run "$lang-disabled" "LANG=${lang}_US.UTF-8 STUB_V4=disabled.kv:503 STUB_V6=disabled.kv:503"
	run "$lang-limits" "LANG=${lang}_US.UTF-8 STUB_V4=limit-ip.kv:429 STUB_V6=limit-site.kv:429"
	run "$lang-unreachable" "LANG=${lang}_US.UTF-8"
	run "$lang-future-schema" "LANG=${lang}_US.UTF-8 STUB_V4=future-schema.kv:200"
done
run "lang-flag-overrides-env" "LANG=en_US.UTF-8 STUB_V4=full-v4.kv:200" -l zh -4
check "the language is asked of the server" logged "lang=zh"
run "ascii-marks-without-utf8" "LANG=C STUB_V4=full-v4.kv:200" -4

# Exit codes: a result from either family is success; no result at all is failure.
run "exit-one-family" "STUB_V4=full-v4.kv:200"
check "exit code 0 with one family" exits_with 0
run "exit-none" "STUB_V4=disabled.kv:503"
check "exit code 1 with none" exits_with 1

# -4 and -6 ask over one family only; every request carries the client header and User-Agent.
run "flag-4" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200" -4
check "-4 makes one IPv4 request" one_request 4 6
check "client header sent" logged "X-IPLense-CLI: 1"
check "User-Agent sent" logged "IPLense-CLI/1.0.0"
run "flag-6" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200" -6
check "-6 makes one IPv6 request" one_request 6 4

# Hostile server text: no escape, bell, carriage return or C1 control reaches the terminal.
run "hostile-text" "STUB_V4=hostile-v4.kv:200" -4
check "no control characters from the server" no_controls

# JSON: both families in one object; a family with no connection says so.
run "json" "STUB_V4=full-v4.kv:200" -j
check "json requests format=json" logged "format=json"

# -o saves the same text without colour codes and leaves no other file.
run "save" "STUB_V4=full-v4.kv:200" -4 -o tests/.work/saved.txt
check "-o file matches the output" saved_matches
check "-o file has no escape codes" saved_plain

# Local checks: every state of every check, over the family that reached the server.
for lang in en zh; do
	run "$lang-local-available" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200" -4
	run "$lang-local-unavailable" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_LOCAL=unavailable STUB_SMTP=refused" -4
	# Rate-limited server (no AI lists, so ChatGPT and Claude show the region only), and the rest of the states.
	run "$lang-local-mixed" "LANG=${lang}_US.UTF-8 STUB_V4=limit-ip.kv:429 STUB_LOCAL=mixed STUB_SMTP=silent" -4
done
gemini_region() { grep -q "^  Gemini  *[^ ].*  $1\$" "tests/snapshots/$2.txt"; }
check "Gemini CAN is shown as CA" gemini_region CA en-local-available
check "an unknown three-letter code is shown as it is" gemini_region XQZ zh-local-mixed
# A proxy that carries the IPv6 request out over IPv4: the IPv6 line says so instead of repeating the IPv4 result.
for lang in en zh; do run "$lang-family-mismatch-line" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_V6=family-mismatch.kv:200"; done
check "each request names its family" logged "X-IPLense-Family: 4"
# The exit the AI traces see: named under the title when it is not the IP checked above, silent when it is.
grep -q "^Local checks · IPv4$" tests/snapshots/en-local-available.txt
check "same exit: the title stays as it is" test $? -eq 0
for lang in en zh; do run "$lang-local-exit-differs" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_LOCAL=exit-differs" -4; done
run "local-v6-exit-differs" "STUB_V6=full-v6.kv:200 STUB_LOCAL=exit-differs" -6
run "json-local-exit" "STUB_V4=full-v4.kv:200 STUB_LOCAL=exit-differs" -j -4
json_exit() { grep -q '"local":{"family":4,"exitIp":"198.51.100.7"' "tests/snapshots/json-local-exit.txt"; }
check "-j names the exit the platforms see" json_exit
run "local-disney-broken" "STUB_V4=full-v4.kv:200 STUB_LOCAL=disney-broken" -4
disney_requests() { [ "$(grep -c bamgrid "$STUB_LOG")" = "$1" ]; }
check "a Disney+ step that fails stops there" disney_requests 1
run "local-available-requests" "STUB_V4=full-v4.kv:200" -4
check "Disney+ takes three requests" disney_requests 3
run "local-dual-stack" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200"
platform_family() { ! grep -v 'iplense.cc' "$STUB_LOG" | grep -qv -- "^-$1 "; }
check "dual stack: local checks over IPv4" platform_family 4
run "local-v6-only" "STUB_V6=full-v6.kv:200"
check "IPv6 only: local checks over IPv6" platform_family 6
run "local-none-without-server" ""
no_platforms() { ! grep -qv 'iplense.cc' "$STUB_LOG"; }
check "no local checks when nothing reaches the server" no_platforms
run "json-local" "STUB_V4=full-v4.kv:200" -j -4

run "help-en" "" -h
run "help-zh" "" -l zh -h
run "version" "" -V

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
