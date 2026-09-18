#!/bin/bash
# Runs each .bend file given (default: every *.bend beside this script that
# carries #| lines) on the JS backend and compares what it prints with its #|
# lines, the way Bend's own tests are pinned: trailing blanks are ignored and a
# nonzero exit adds a final "exit N" line. Exits 1 if any file misses.
set -u
cd "$(dirname "$0")" || exit 1
[ $# -eq 0 ] && set -- $(grep -l '^#|' ./*.bend)
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
exit $status
