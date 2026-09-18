import Base
import ./sim.bend as S
import ./circuits.bend as G

# The timing harness for the native build: NL layers of H on every one of NQ
# qubits, then the norm of the state, which is one more pass. bench.sh
# substitutes NQ and NL and builds one binary per size.
def layers(k: Nat, +n: Nat) -> List<&2, S.Op>:
  match k:
    case 0n:
      Nil{}
    case 1n+j:
      List.append(&2, S.Op, G.each(~G.h, n), layers(j, n))

# n stays a variable here: a concrete S.Q(24n) in a checked type unfolds into
# a pair type with 2^24 leaves and takes the checker down with it
def bench(+n: Nat, k: Nat) -> F32:
  S.norm2(n, S.run(n, layers(k, n), S.ket0(n)))

def main() -> IO(Unit):
  IO.print(F32.show(bench(NQ, NL)))
