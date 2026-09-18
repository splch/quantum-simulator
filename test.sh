#!/bin/bash
# Runs each .bend file given (default: every *.bend beside this script that
# carries #| lines) on the JS backend and compares what it prints with its #|
# lines, the way Bend's own tests are pinned: trailing blanks are ignored and a
# nonzero exit adds a final "exit N" line. With no arguments it also runs the
# numpy differential test, ref.py. Exits 1 if anything misses.
set -u
cd "$(dirname "$0")" || exit 1
all=$#
# the exact build: the same sim.bend and circuits.bend over exact.bend
sed 's#import ./amp.bend as A#import ./exact.bend as A#' sim.bend > sim_x.bend
sed 's#import ./amp.bend as A#import ./exact.bend as A#; s#import ./sim.bend as S#import ./sim_x.bend as S#' circuits.bend > circuits_x.bend
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
if [ "$all" -eq 0 ]; then
  # the OpenQASM reader on each example, against the golden beside it
  for ex in examples/*.qasm; do
    want="${ex%.qasm}.out"
    [ -f "$want" ] || continue
    got=$(QASM="$ex" SHOTS=4096 bend qasm.bend 2>&1)
    if [ "$got" = "$(cat "$want")" ]; then echo "PASS qasm.bend $ex"; else echo "FAIL qasm.bend $ex"; diff <(cat "$want") <(printf '%s\n' "$got") | sed 's/^/  /'; status=1; fi
  done
  if uv run ref.py; then echo "PASS ref.py"; else echo "FAIL ref.py"; status=1; fi
  if uv run ref.py --exact; then echo "PASS ref.py --exact"; else echo "FAIL ref.py --exact"; status=1; fi
fi
exit $status
