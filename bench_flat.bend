import Base
import ./sim.bend as S
import ./circuits.bend as G
import ./flat.bend as F

# The timing harness for the hybrid: NL layers of H on every one of NQ
# qubits, on a tree of depth NM = NQ - LB over blocks of 2^LB amplitudes,
# then the norm. bench.sh substitutes NQ, NL, NM and LB and builds one binary
# per size. NQ and NM stay variables inside the checked signatures.
def layers(k: Nat, +n: Nat) -> List<&2, S.Op>:
  match k:
    case 0n:
      Nil{}
    case 1n+j:
      List.append(&2, S.Op, G.each(~G.h, n), layers(j, n))

def bench(+m: Nat, +lb: Nat, k: Nat) -> F32:
  F.norm2f(m, lb, F.runf(m, lb, layers(k, Nat.add(m, lb)), F.ketf(m, lb)))

def main() -> IO(Unit):
  IO.print(F32.show(bench(NM, LB, NL)))
