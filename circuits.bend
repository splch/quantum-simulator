import Base
import ./amp.bend as A
import ./sim.bend as S

# Gate constructors, each returning one Op. Qubit indices count from the root,
# so qubit 0 is the leftmost printed bit.

# gate g on target q with controls cs
def ctrl(cs: List<&2, Nat>, q: Nat, g: A.Gate) -> S.Op:
  S.Op{q, cs, g}

def h(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.H()}

def x(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.X()}

def y(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.Y()}

def z(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.Z()}

def s(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.S()}

def sdg(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.Sdg()}

def t(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.T()}

def tdg(q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.Tdg()}

def p(phi: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.P(phi)}

def rx(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RX(theta)}

def ry(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RY(theta)}

def rz(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RZ(theta)}

def cx(c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.X()}

def cz(c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.Z()}

def ccx(c1: Nat, c2: Nat, q: Nat) -> S.Op:
  S.Op{q, [c1, c2], A.X()}

def cp(phi: F32, c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.P(phi)}

# Circuits
# --------
# A circuit is a list of ops. The helpers below return lists; join them with
# List.append(&2, S.Op, a, b) or List.concat(&2, S.Op, [a, b, c]). Binders in
# this file avoid the names p and t, which are gates here.

# swap as three CNOTs
def swap(+a: Nat, +b: Nat) -> List<&2, S.Op>:
  [cx(a, b), cx(b, a), cx(a, b)]

# the gate f on every qubit below n: f(n-1), ..., f(0)
def each(~f: Nat -> S.Op, n: Nat) -> List<&2, S.Op>:
  match n:
    case 0n:
      Nil{}
    case 1n++j:
      f(j) <> each(~f, j)

# Z controlled by every other qubit: a sign flip on |1..1>
def mcz(+n: Nat) -> S.Op:
  ctrl(List.range(Nat.sub(n, 1n)), Nat.sub(n, 1n), A.Z())

# X on each qubit whose marked bit is 0, so that the marked bitstring becomes
# |1..1>; the bits are listed from qubit k on
def flips(bits: List<&2, Bool>, +k: Nat) -> List<&2, S.Op>:
  match bits:
    case Nil{}:
      Nil{}
    case False{} <> rest:
      x(k) <> flips(rest, 1n+k)
    case True{} <> rest:
      flips(rest, 1n+k)

# Grover: the oracle flips the sign of the marked bitstring (root first); the
# diffusion is 2|s><s| - I up to a global sign, as H, X, a sign flip on
# |1..1>, X, H on every qubit
def oracle(n: Nat, +bits: List<&2, Bool>) -> List<&2, S.Op>:
  List.concat(&2, S.Op, [flips(bits, 0n), [mcz(n)], flips(bits, 0n)])

def diffusion(+n: Nat) -> List<&2, S.Op>:
  List.concat(&2, S.Op, [each(~h, n), each(~x, n), [mcz(n)], each(~x, n), each(~h, n)])

# one Grover iteration for the marked bitstring
def grover(+n: Nat, bits: List<&2, Bool>) -> List<&2, S.Op>:
  List.append(&2, S.Op, oracle(n, bits), diffusion(n))

# The quantum Fourier transform, big-endian (qubit 0 is the most significant
# bit): H on each qubit followed by controlled phases pi/2, pi/4, ... from the
# qubits below it, n(n+1)/2 gates in all, then floor(n/2) swaps that reverse
# the bit order.

# CP(angle) onto tg from c, then angle/2 from c+1, and so on, d times
def qft.rots(d: Nat, +tg: Nat, +c: Nat, +angle: F32) -> List<&2, S.Op>:
  match d:
    case 0n:
      Nil{}
    case 1n+e:
      cp(angle, c, tg) <> qft.rots(e, tg, 1n+c, F32.mul(angle, 0.5))

# the H and rotations of qubits off .. off+m-1
def qft.go(m: Nat, +off: Nat) -> List<&2, S.Op>:
  match m:
    case 0n:
      Nil{}
    case 1n++r:
      h(off) <> List.append(&2, S.Op, qft.rots(r, off, 1n+off, F32.mul(F32.pi(), 0.5)), qft.go(r, 1n+off))

# k swaps folding the ends inward: (lo, hi), (lo+1, hi-1), ...
def qft.swaps(k: Nat, +lo: Nat, +hi: Nat) -> List<&2, S.Op>:
  match k:
    case 0n:
      Nil{}
    case 1n+j:
      List.append(&2, S.Op, swap(lo, hi), qft.swaps(j, 1n+lo, Nat.sub(hi, 1n)))

def qft(+n: Nat) -> List<&2, S.Op>:
  List.append(&2, S.Op, qft.go(n, 0n), qft.swaps(Nat.div(n, 2n), 0n, Nat.sub(n, 1n)))
