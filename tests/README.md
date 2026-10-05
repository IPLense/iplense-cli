# Tests

`bash tests/run.sh` runs the script against a stub `curl` (`stub/curl`) and fixtures, and compares its output with
`snapshots/`; nothing reaches the network. The stub answers as the real services do, in the family a request is asked
over: a trace fixture's `ip6=` line is its address over IPv6. `UPDATE=1 bash tests/run.sh` rewrites the snapshots after
an intended change.
