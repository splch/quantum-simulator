import Base
import ./sim.bend as S
import ./circuits.bend as G

# The sampling harness: one layer of H on NQ qubits (a uniform superposition),
# then NS shots; prints how many bins were hit and the total count, which must
# be NS. bench.sh substitutes NQ and NS.
def total(bins: List<&2, S.Bin>, acc: Nat) -> Nat:
  match bins:
    case Nil{}:
      acc
    case S.Bin{bits, k} <> rest:
      total(rest, Nat.add(k, acc))

# n stays a variable, as in bench.bend
def bench(+n: Nat, k: U32) -> List<&2, S.Bin>:
  S.sample(n, k, S.seed(), S.run(n, G.each(~G.h, n), S.ket0(n)))

def main() -> IO(Unit):
  +hist = bench(NQ, NS)
  IO.print(Nat.show(List.length(&2, S.Bin, hist)) ++ " bins, " ++ Nat.show(total(hist, 0n)) ++ " shots")
