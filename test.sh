#!/bin/bash
# Runs each .bend file given (default: every tests/*.bend with #| lines) on the
# JS backend and compares what it prints with its #| lines, trailing blanks
# ignored, a nonzero exit added as a final "exit N" line. With no arguments it
# also runs the numpy differential test. Exits 1 if anything misses.
set -u
cd "$(dirname "$0")" || exit 1
all=$#
[ $# -eq 0 ] && set -- $(grep -l '^#|' tests/*.bend)
status=0
for f in "$@"; do
  want=$(sed -n 's/^#|//p' "$f" | sed 's/[[:space:]]*$//')
  got=$(bend "$f" 2>&1; code=$?; [ "$code" -ne 0 ] && echo "exit $code")
  got=$(printf '%s\n' "$got" | sed 's/[[:space:]]*$//')
  if [ "$got" = "$want" ]; then
    echo "PASS $f"
  else
    echo "FAIL $f"
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/  /'
    status=1
  fi
done
if [ "$all" -eq 0 ]; then
  if uv run tests/ref.py; then echo "PASS tests/ref.py"; else echo "FAIL tests/ref.py"; status=1; fi
fi
exit $status
