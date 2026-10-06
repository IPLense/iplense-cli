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
# STUB_TTY=1 has the script write as it does to a terminal (colour, and COLUMNS as the width).
HARNESS='eval "$(sed "\$d" "$0")"
has_net_redirections() { [ "${STUB_SMTP-}" != unsupported ]; }
smtp_address() { [ "${STUB_SMTP-}" != dns ] && printf 192.0.2.25; }
reverse_dns() { printf "host-203-0-113-45.example.test"; }
smtp_greeting() { case ${STUB_SMTP-} in 220) printf "220 mx.example ESMTP" ;; silent) return 2 ;; no220) printf "421 unavailable" ;; timeout) return 143 ;; *) return 1 ;; esac; }
on_terminal() { [ "${STUB_TTY-}" = 1 ]; }
main "$@"'

# run NAME "ENV=VALUE ..." ARGS... : runs the script with that environment, compares stdout+stderr and the exit code.
# Platform pages default to the "available" fixtures and port 25 to a greeting.
run() {
	local name=$1 envs=$2 actual expected
	shift 2
	: >"$STUB_LOG"
	# shellcheck disable=SC2086
	actual=$(env -u STUB_V4 -u STUB_V6 COLUMNS=80 LANG=en_US.UTF-8 STUB_LOCAL=available STUB_SMTP=220 STUB_REPORT=success $envs \
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
one_request() { [ "$(grep 'cli/v1/self' "$STUB_LOG" | grep -c -- "^-$1 ")" = 1 ] && ! grep 'cli/v1/self' "$STUB_LOG" | grep -q -- "^-$2 "; }
logged() { grep -q -- "$1" "$STUB_LOG"; }
no_controls() { ! has_controls "$LAST"; }
saved_matches() { [ "$(cat "$OUT_FILE")" = "$(printf '%s\n' "$LAST" | sed '$d' | sed '$d' | sed '$d' | LC_ALL=C sed -e $'s/\033\\[[0-9;]*m//g' -e 's/ *$//')" ]; }
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
		run "$lang-$cols-v4" "LANG=${lang}_US.UTF-8 COLUMNS=$cols STUB_V4=full-v4.kv:200" -4
		run "$lang-$cols-v6" "LANG=${lang}_US.UTF-8 COLUMNS=$cols STUB_V6=full-v6.kv:200" -6
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
# -l cn is the same as -l zh.
run "lang-cn-alias" "LANG=en_US.UTF-8 STUB_V4=full-v4.kv:200" -l cn -4
same_as_zh() { [ "$(cat tests/snapshots/lang-cn-alias.txt)" = "$(cat tests/snapshots/lang-flag-overrides-env.txt)" ]; }
check "-l cn prints what -l zh does" same_as_zh
check "-l cn asks the server for zh" logged "lang=zh"
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
check "User-Agent sent" logged "IPLense-CLI/$(sed -n 's/^VERSION=//p' iplense.sh)"
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
# The website's example (iplense.cc/{zh,en}/cli shows these files): IPv4 with local checks at 120 columns, from a fixture equal
# to full-v4.kv but with a city short enough that no cell is cut; the example must show no ellipsis.
# Phones (below 767px) show the 80-column example, wider screens the 120-column one.
for lang in en zh; do for cols in 80 120; do run "$lang-$cols-page-example" "LANG=${lang}_US.UTF-8 COLUMNS=$cols STUB_V4=page-v4.kv:200 STUB_LOCAL=page" -4; done; done
no_ellipsis() { ! grep -q '…' "tests/snapshots/$1.txt"; }
for name in en-80 zh-80 en-120 zh-120; do check "the page example has no cut cell ($name)" no_ellipsis "$name-page-example"; done
# The page shows the example in colour (from these snapshots, as a terminal shows them); without its colour codes and the
# spaces a label leaves at a line end, each is the plain example.
for lang in en zh; do for cols in 80 120; do run "$lang-$cols-page-example-color" "LANG=${lang}_US.UTF-8 COLUMNS=$cols TERM=xterm STUB_TTY=1 STUB_V4=page-v4.kv:200 STUB_LOCAL=page" -4; done; done
plain_of_color() { [ "$(LC_ALL=C sed -e "s/$(printf '\033')\[[0-9;]*m//g" -e 's/ *$//' "tests/snapshots/$1-page-example-color.txt")" = "$(cat "tests/snapshots/$1-page-example.txt")" ]; }
has_color() { LC_ALL=C grep -q "$(printf '\033')\[97;42m" "tests/snapshots/$1-page-example-color.txt"; }
for name in en-80 zh-80 en-120 zh-120; do
	check "the coloured example is the plain one ($name)" plain_of_color "$name"
	check "the coloured example has labels ($name)" has_color "$name"
done
# NO_COLOR and -o stay plain on a terminal; so does the output when it is not a terminal (every other snapshot).
run "no-color-on-terminal" "TERM=xterm STUB_TTY=1 NO_COLOR=1 STUB_V4=full-v4.kv:200" -4
check "NO_COLOR: no escape codes" no_controls
gemini_region() {
	STUB_LOCAL=available answers available gemini "available $1"
}
# shellcheck disable=SC2016 # Expanded by the child Bash.
check "Gemini CAN is shown as CA" bash -c 'eval "$(sed "\$d" "$0")"; [ "$(alpha2 CAN)" = CA ]' "$ROOT/iplense.sh"
# shellcheck disable=SC2016 # Expanded by the child Bash.
check "an unknown three-letter code is shown as it is" bash -c 'eval "$(sed "\$d" "$0")"; [ "$(alpha2 XQZ)" = XQZ ]' "$ROOT/iplense.sh"

# One local check's own answer ("status region") with the platform pages of tests/fixtures/local/SCENARIO.
# shellcheck disable=SC2016 # expanded by the inner bash, not here.
answer() { STUB_LOCAL=$1 bash -c 'eval "$(sed "\$d" "$0")"; LOCAL_FAMILY=4; "check_$1"' "$ROOT/iplense.sh" "$2"; }
answers() { [ "$(answer "$1" "$2")" = "$3" ]; }
check "Gemini: NotebookLM's redirect to notebook.google.com is available" answers available gemini 'available CA'
check "Gemini: NotebookLM's location=unsupported is unavailable" answers unavailable gemini 'unavailable'
check "Gemini: a restricted region on the page outranks the old flag and NotebookLM" answers gemini-restricted gemini 'unavailable CN'
check "Gemini: Google's sorry page is a failed check" answers gemini-sorry gemini 'failed'
check "Gemini: HTTP 451 is unavailable" answers gemini-blocked-status gemini 'unavailable'
check "Gemini: the old false flag alone is unavailable" answers gemini-false-flag gemini 'unavailable US'
check "Gemini: the old true flag without a verdict is available" answers mixed gemini 'available XQZ'
check "Gemini: a page with neither a flag nor a verdict is a failed check" answers gemini-silent gemini 'failed'
check "YouTube: an offer with one stated region is available there" answers available youtube 'available CA'
check "YouTube: a redirect to google.cn is unavailable" answers youtube-cn youtube 'unavailable'
check "YouTube: the not-available notice outranks an offer" answers youtube-region-text youtube 'unavailable'
check "YouTube: an offer with two stated regions shows none" answers youtube-two-regions youtube 'available'
check "YouTube: ad-free text without an offer is a failed check" answers youtube-no-offer youtube 'failed'
check "YouTube: a consent page is a failed check" answers mixed youtube 'failed'
# shellcheck disable=SC2016 # expanded by the inner shells, not here.
check "Gemini asks NotebookLM without following the redirect, over the same family" \
	sh -c ': >"$1"; STUB_LOCAL=available bash -c '"'"'eval "$(sed "\$d" "$0")"; LOCAL_FAMILY=6; check_gemini >/dev/null'"'"' "$2"; grep -q -- "^-6 .*notebooklm.google.com" "$1" && ! grep "notebooklm" "$1" | grep -q -- " -L "' _ "$STUB_LOG" "$ROOT/iplense.sh"
# A proxy that carries the IPv6 request out over IPv4: the IPv6 line says so instead of repeating the IPv4 result.
for lang in en zh; do run "$lang-family-mismatch-line" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_V6=family-mismatch.kv:200"; done
# The address it arrived from is named only when the header does not show it already (no IPv4 result here).
run "family-mismatch-without-result" "STUB_V4=limit-ip.kv:429 STUB_V6=family-mismatch.kv:200"
names_address() { grep -q 'arrived over IPv4 (203.0.\*.\*)$' tests/snapshots/family-mismatch-without-result.txt; }
check "the mismatch line names the address when nothing else does" names_address
check "each request names its family" logged "X-IPLense-Family: 4"
# The exit the AI traces see: named under the title when it is not the IP checked above, silent when it is.
same_exit() { ! grep -q '^  exit ' tests/snapshots/en-local-available.txt; }
check "same exit: no differing-exit notice" same_exit
for lang in en zh; do run "$lang-local-exit-differs" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_LOCAL=exit-differs" -4; done
run "local-v6-exit-differs" "STUB_V6=full-v6.kv:200 STUB_LOCAL=exit-differs" -6
run "json-local-exit" "STUB_V4=full-v4.kv:200 STUB_LOCAL=exit-differs" -j -4
json_exit() { grep -q '"local":{"family":4,"exitIp":"198.51.*.*"' "tests/snapshots/json-local-exit.txt"; }
check "-j names the exit the platforms see" json_exit
run "local-disney-broken" "STUB_V4=full-v4.kv:200 STUB_LOCAL=disney-broken" -4
disney_requests() { [ "$(grep -c bamgrid "$STUB_LOG")" = "$1" ]; }
check "a failed Disney+ registration sends no further requests" disney_requests 1
run "local-available-requests" "STUB_V4=full-v4.kv:200" -4
check "Disney+ registers once, without token exchange" disney_requests 1
run "local-dual-stack" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200"
platform_family() { ! grep -v 'iplense.cc' "$STUB_LOG" | grep -qv -- "^-$1 "; }
both_families() { grep -v 'iplense.cc' "$STUB_LOG" | grep -q '^\-4 ' && grep -v 'iplense.cc' "$STUB_LOG" | grep -q '^\-6 '; }
check "dual stack: local checks over each tested family" both_families
run "local-v6-only" "STUB_V6=full-v6.kv:200"
check "IPv6 only: local checks over IPv6" platform_family 6
run "local-none-without-server" ""
no_platforms() { ! grep -qv 'iplense.cc' "$STUB_LOG"; }
check "no local checks when nothing reaches the server" no_platforms
run "json-local" "STUB_V4=full-v4.kv:200" -j -4

# Every new option, SMTP classification and report outcome is a snapshot and a behavioral assertion.
for lang in en zh; do
	run "$lang-full" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200" -f
	run "$lang-private" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200" -4 -p
	run "$lang-json-full" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200" -j -f -4
	for smtp in 220 refused timeout silent no220 dns unsupported; do
		run "$lang-port25-$smtp" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_SMTP=$smtp" -4
	done
	for report in success limited disabled expired mismatch invalid network; do
		run "$lang-report-$report" "LANG=${lang}_US.UTF-8 STUB_V4=full-v4.kv:200 STUB_REPORT=$report" -4
		check "report $report never changes a successful self-check's exit" exits_with 0
	done
done
run "risk-partial" "STUB_V4=risk-partial-v4.kv:200" -4 -p
run "zh-save" "LANG=zh_CN.UTF-8 STUB_V4=full-v4.kv:200" -4 -o tests/.work/saved.txt
check "Chinese -o file is the printed report" saved_matches
run "private-no-upload" "STUB_V4=full-v4.kv:200" -p -4
no_upload() { ! grep -q '/cli/v1/report' "$STUB_LOG"; }
check "-p never uploads" no_upload
run "json-no-upload" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200" -j
check "-j never uploads" no_upload
run "save-private" "TERM=xterm STUB_TTY=1 STUB_V4=full-v4.kv:200" -p -4 -o tests/.work/saved.txt
check "-o file matches a terminal's report without colours" saved_matches
check "-o file has no progress or colours" saved_plain
check "real TTY progress and its three suppression paths" python3 tests/assert-progress.py
run "report-contract" "STUB_V4=full-v4.kv:200 STUB_V6=full-v6.kv:200 STUB_LOCAL=exit-differs" -f
# Inspect the allowed upload independently of the rendered report.
check "-f still sends only masked exit addresses" python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert {x["family"] for x in d["local"]}=={4,6}; assert all(x["exitDiffers"] and "*" in x["exitIp"] for x in d["local"])' tests/.work/report.json


# Terminal output fits both widths and loses no part of a long fixture location.
check "80/120 snapshots never exceed their terminal width" python3 tests/assert-output.py

run "help-en" "" -h
run "help-zh" "" -l zh -h
run "version" "" -V

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
