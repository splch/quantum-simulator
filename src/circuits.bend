import Base
import ./sim.bend as S

# Gate constructors, one Op each, and a few circuits. Qubit indices count from
# the root, so qubit 0 is the leftmost printed bit. Binders here avoid the
# names p, t, h and s, which are gates.

def one(g: S.Gate, q: Nat) -> S.Op:
  S.Op{q, Nil{}, g}

def ctrl(cs: List<&2, Nat>, q: Nat, g: S.Gate) -> S.Op:
  S.Op{q, cs, g}

def h(q: Nat) -> S.Op:
  one(S.H(), q)

def x(q: Nat) -> S.Op:
  one(S.X(), q)

def y(q: Nat) -> S.Op:
  one(S.Y(), q)

def z(q: Nat) -> S.Op:
  one(S.Z(), q)

def s(q: Nat) -> S.Op:
  one(S.S(), q)

def sdg(q: Nat) -> S.Op:
  one(S.Sdg(), q)

def t(q: Nat) -> S.Op:
  one(S.T(), q)

def tdg(q: Nat) -> S.Op:
  one(S.Tdg(), q)

def cx(c: Nat, q: Nat) -> S.Op:
  ctrl([c], q, S.X())

def cz(c: Nat, q: Nat) -> S.Op:
  ctrl([c], q, S.Z())

def ccx(c1: Nat, c2: Nat, q: Nat) -> S.Op:
  ctrl([c1, c2], q, S.X())

def p(phi: F32, q: Nat) -> S.Op:
  one(S.P(phi), q)

def rx(theta: F32, q: Nat) -> S.Op:
  one(S.RX(theta), q)

def ry(theta: F32, q: Nat) -> S.Op:
  one(S.RY(theta), q)

def rz(theta: F32, q: Nat) -> S.Op:
  one(S.RZ(theta), q)

# OpenQASM's U3(theta, phi, lambda):
# [[cos(theta/2), -e^(i lambda) sin(theta/2)], [e^(i phi) sin(theta/2), e^(i (phi+lambda)) cos(theta/2)]]
def u3(theta: F32, +phi: F32, +lambda: F32, q: Nat) -> S.Op:
  +half = F32.mul(theta, 0.5)
  +co = F32.cos(half)
  +si = F32.sin(half)
  +pl = F32.add(phi, lambda)
  one(S.U(S.C{co, 0.0}, S.C{F32.neg(F32.mul(F32.cos(lambda), si)), F32.neg(F32.mul(F32.sin(lambda), si))}, S.C{F32.mul(F32.cos(phi), si), F32.mul(F32.sin(phi), si)}, S.C{F32.mul(F32.cos(pl), co), F32.mul(F32.sin(pl), co)}), q)

# U2(phi, lambda) = U3(pi/2, phi, lambda)
def u2(phi: F32, lambda: F32, q: Nat) -> S.Op:
  u3(F32.mul(F32.pi(), 0.5), phi, lambda, q)

def cp(phi: F32, c: Nat, q: Nat) -> S.Op:
  ctrl([c], q, S.P(phi))

# Circuits are lists of ops; join them with List.append(&2, S.Op, a, b) or
# List.concat(&2, S.Op, [a, b, c]).

def swap(+a: Nat, +b: Nat) -> List<&2, S.Op>:
  [cx(a, b), cx(b, a), cx(a, b)]

# f(n-1), ..., f(0)
def each(~f: Nat -> S.Op, n: Nat) -> List<&2, S.Op>:
  match n:
    case 0n:
      Nil{}
    case 1n++j:
      f(j) <> each(~f, j)

# Z controlled by every other qubit: a sign flip on |1..1>
def mcz(+n: Nat) -> S.Op:
  ctrl(List.range(Nat.sub(n, 1n)), Nat.sub(n, 1n), S.Z())

# X on each qubit, from k on, whose marked bit is 0, so the marked bitstring
# becomes |1..1>
def flips(bits: List<&2, Bool>, +k: Nat) -> List<&2, S.Op>:
  match bits:
    case Nil{}:
      Nil{}
    case False{} <> rest:
      x(k) <> flips(rest, 1n+k)
    case True{} <> rest:
      flips(rest, 1n+k)

# Grover: the oracle flips the sign of the marked bitstring (root first), and
# the diffusion is 2|s><s| - I up to a global sign
def oracle(n: Nat, +bits: List<&2, Bool>) -> List<&2, S.Op>:
  List.concat(&2, S.Op, [flips(bits, 0n), [mcz(n)], flips(bits, 0n)])

def diffusion(+n: Nat) -> List<&2, S.Op>:
  List.concat(&2, S.Op, [each(~h, n), each(~x, n), [mcz(n)], each(~x, n), each(~h, n)])

def grover(+n: Nat, bits: List<&2, Bool>) -> List<&2, S.Op>:
  List.append(&2, S.Op, oracle(n, bits), diffusion(n))

# The QFT, big-endian: H on each qubit, then controlled phases pi/2, pi/4, ..
# from the qubits below it, n(n+1)/2 gates in all, then floor(n/2) swaps that
# reverse the bit order.

# CP(angle) onto tg from c, angle/2 from c+1, and so on, d times
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

# k swaps folding the ends inward: (lo, hi), (lo+1, hi-1), ..
def qft.swaps(k: Nat, +lo: Nat, +hi: Nat) -> List<&2, S.Op>:
  match k:
    case 0n:
      Nil{}
    case 1n+j:
      List.append(&2, S.Op, swap(lo, hi), qft.swaps(j, 1n+lo, Nat.sub(hi, 1n)))

def qft(+n: Nat) -> List<&2, S.Op>:
  List.append(&2, S.Op, qft.go(n, 0n), qft.swaps(Nat.div(n, 2n), 0n, Nat.sub(n, 1n)))
