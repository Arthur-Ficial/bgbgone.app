#!/bin/zsh
# bgbgone-mock — stand-in for the real bgbgone CLI in tests.
#
# Behaviour controlled by environment variables (the test sets them before invoking):
#   MOCK_STDOUT      — string emitted on stdout (default: a valid RunResult JSON line)
#   MOCK_STDERR      — string emitted on stderr (default: empty)
#   MOCK_EXIT        — exit code (default: 0)
#   MOCK_DELAY       — seconds to sleep before exiting (default: 0)
#
# When MOCK_STDOUT is unset, derive a "happy path" JSON line from the -o argument
# so the real argv contract is exercised end-to-end.
set -e

INPUT=""
OUTPUT=""
NEXT=""
for arg in "$@"; do
    case "$NEXT" in
        output) OUTPUT="$arg"; NEXT="" ;;
        *) ;;
    esac
    case "$arg" in
        -o|--output) NEXT="output" ;;
        --json|--quiet|--bg|--bg-fit|--to) ;;
        -*) ;;
        *) [[ -z "$INPUT" ]] && INPUT="$arg" ;;
    esac
done

DEFAULT_JSON='{"input":"'"$INPUT"'","output":"'"$OUTPUT"'","algo":"vn-mask","format":"png","width":1024,"height":768}'

[[ -n "${MOCK_DELAY:-}" ]] && sleep "$MOCK_DELAY"
[[ -n "${MOCK_STDERR:-}" ]] && print -u 2 -- "$MOCK_STDERR"

if [[ -n "${MOCK_STDOUT:-}" ]]; then
    print -- "$MOCK_STDOUT"
else
    print -- "$DEFAULT_JSON"
fi

exit "${MOCK_EXIT:-0}"
