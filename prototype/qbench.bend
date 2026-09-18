import Base
import ./q.bend as S

def skips(n: Nat) -> List<&2, S.Role>:
  match n:
    case 0n:
      Nil{}
    case 1n++p:
      S.Skip{} <> skips(p)

# roles for a one-qubit gate on qubit k of n (k counted from the root)
def roles(n: Nat, k: Nat) -> List<&2, S.Role>:
  match n k:
    case 0n _:
      Nil{}
    case 1n++p 0n:
      S.Targ{} <> skips(p)
    case 1n++p 1n++j:
      S.Skip{} <> roles(p, j)

# H on qubits k-1 .. 0
def hall(k: Nat, +n: Nat, q: S.Q(n)) -> S.Q(n):
  match k:
    case 0n:
      q
    case 1n++j:
      hall(j, n, S.apply(n, roles(n, j), S.H(), q))

# k layers of H on every qubit
def layers(k: Nat, +n: Nat, q: S.Q(n)) -> S.Q(n):
  match k:
    case 0n:
      q
    case 1n++j:
      layers(j, n, hall(n, n, q))

def norm(n: Nat, q: S.Q(n)) -> F32:
  match n:
    case 0n:
      S.C.norm2(q)
    case 1n++p:
      (l, r) = q
      a b = norm(p, l) norm(p, r)
      F32.add(a, b)

def run(+n: Nat, k: Nat) -> F32:
  norm(n, layers(k, n, S.ket0(n)))

def main() -> IO(Unit):
  IO.print(F32.show(run(NQ, NL)))
