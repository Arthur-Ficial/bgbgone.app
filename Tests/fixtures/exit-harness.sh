#!/bin/zsh
# exit-harness — a generic subprocess behaviour driver. NOT a bgbgone CLI stand-in.
#
# It exists solely so BgBgOneRunnerTests can exercise BgBgOneRunner's PROCESS handling
# — exit-code → RunnerError mapping, stderr-tail capture, garbage-stdout handling, and
# cancellation — deterministically. It deliberately knows NOTHING about bgbgone's argv
# or JSON: it never emits a success envelope, so it CANNOT fake the wire contract.
#
# The real success contract (argv + the {ok,schema,result} JSON) is proven ONLY by the
# real pinned binary in RealBinaryE2ETests.
#
# Behaviour controlled entirely by environment variables:
#   MOCK_STDOUT  — string emitted on stdout (default: empty)
#   MOCK_STDERR  — string emitted on stderr (default: empty)
#   MOCK_EXIT    — exit code (default: 0)
#   MOCK_DELAY   — seconds to sleep before exiting (default: 0)
set -e

[[ -n "${MOCK_DELAY:-}" ]] && sleep "$MOCK_DELAY"
[[ -n "${MOCK_STDERR:-}" ]] && print -u 2 -- "$MOCK_STDERR"
[[ -n "${MOCK_STDOUT:-}" ]] && print -- "$MOCK_STDOUT"

exit "${MOCK_EXIT:-0}"
