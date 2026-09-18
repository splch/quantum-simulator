#!/bin/bash
# Native benchmarks. For each "qubits:layers" argument, builds bench.bend with
# NQ and NL substituted and runs it with --threads 1 and with every core,
# printing the wall time and peak memory of each run. With a "sample:qubits:shots"
# argument it builds bench_sample.bend instead. Generated sources and binaries
# are bench_gen_* (gitignored) and are removed afterwards.
#   ./bench.sh 20:5 24:2            # gates
#   ./bench.sh sample:24:10000      # sampling
#   THREADS=1 ./bench.sh 28:1       # one lane only
set -u
cd "$(dirname "$0")" || exit 1
lanes=${THREADS:-"1 all"}
run() {  # run <binary> <threads|all>: wall, user and sys seconds, peak memory, then what the program printed
  local bin=$1 t=$2 out=$(mktemp) err=$(mktemp)
  if [ "$t" = all ]; then { /usr/bin/time -l "$bin" > "$out"; } 2> "$err"; else { /usr/bin/time -l "$bin" --threads "$t" > "$out"; } 2> "$err"; fi
  local times=$(awk '/real/ {printf "%s real %s user %s sys", $1, $3, $5}' "$err")
  local rss=$(awk '/maximum resident set size/ {printf "%.0f MB", $1/1048576}' "$err")
  local res=$(cat "$out"; grep -v -E '(real|user|sys)$|^ +[0-9]+  [a-z]' "$err")
  printf "  threads %-3s %-34s %10s  %s\n" "$t" "$times" "$rss" "$(echo $res)"
  rm -f "$out" "$err"
}
for spec in "$@"; do
  case $spec in
    sample:*) IFS=: read -r _ nq ns <<< "$spec"; src=bench_gen_s${nq}_${ns}.bend
              sed "s/NQ/${nq}n/g; s/NS/${ns}/g" bench_sample.bend > "$src"
              echo "sample: $nq qubits, $ns shots" ;;
    *)        IFS=: read -r nq nl <<< "$spec"; src=bench_gen_${nq}_${nl}.bend
              sed "s/NQ/${nq}n/g; s/NL/${nl}n/g" bench.bend > "$src"
              echo "gates: $nq qubits, $nl layers = $((nq * nl)) H gates" ;;
  esac
  bin=${src%.bend}
  if ! bend "$src" -o "$bin" > /dev/null 2>&1; then echo "  build failed:"; bend "$src" -o "$bin" 2>&1 | head -5; rm -f "$src"; continue; fi
  for t in $lanes; do run "./$bin" "$t"; done
  rm -f "$src" "$bin"
done
