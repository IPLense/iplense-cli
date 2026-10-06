# Tests

`bash tests/run.sh` runs the script against a stub `curl` (`stub/curl`) and fixtures, compares its output with
`snapshots/`, and checks behavior. No request reaches the network. Test dependencies are Bash, Python 3 and the usual
system text tools; `shellcheck` is the separate static check.

The matrix includes Chinese/English, 80/120 columns, both IP families and either one alone, `-f`, `-p`, `-j`, `-o`, SMTP's
three states (220, refused, timeout, silent, non-220, DNS failure and unsupported Bash), report success/limit/disabled/
expired/mismatched/invalid/network failure, `NO_COLOR`, ASCII marks, and a partial risk-module failure.

`assert-output.py` independently checks display widths, masked addresses (including repeated JSON fields), absence of
full-result links and the exact bounded report request. `assert-progress.py` uses a real PTY to verify platform names,
progress and clearing, then verifies that non-TTY, `-j` and `-o` suppress progress. SMTP capability/resolution/greetings
are substituted in the snapshot harness; real socket and operating-system validation is separate from these tests.

A trace fixture's `ip6=` line is its address over IPv6. The `local/page` replies use JP, matching the page example's
location. Fixture tokens and report IDs are synthetic. `STUB_TTY=1` writes as a terminal for coloured snapshots;
`COLUMNS` is the width. `UPDATE=1 bash tests/run.sh` rewrites snapshots after an intended output change; copy the eight
`{en,zh}-{80,120}-page-example{,-color}.txt` files to the application's `code/content/cli/examples/` together with the
script copy. `CliPageTest` and `CliScriptTest` compare these bytes.
