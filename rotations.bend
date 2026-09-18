import Base
import ./amp.bend as A
import ./sim.bend as S
import ./circuits.bend as G

# Gates with an angle, and the QFT built from them. These exist only with the
# F32 scalar module: a rotation by an angle has no exact form in D[w].

def p(phi: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.P(phi)}

def rx(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RX(theta)}

def ry(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RY(theta)}

def rz(theta: F32, q: Nat) -> S.Op:
  S.Op{q, Nil{}, A.RZ(theta)}

# the general one-qubit gate of OpenQASM: U3(theta, phi, lambda) is
# [[cos(theta/2), -e^(i lambda) sin(theta/2)], [e^(i phi) sin(theta/2), e^(i (phi+lambda)) cos(theta/2)]]
def u3(theta: F32, +phi: F32, +lambda: F32, q: Nat) -> S.Op:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  +pl = F32.add(phi, lambda)
  S.Op{q, Nil{}, A.U(A.C{c, 0.0}, A.C{F32.neg(F32.mul(F32.cos(lambda), s)), F32.neg(F32.mul(F32.sin(lambda), s))}, A.C{F32.mul(F32.cos(phi), s), F32.mul(F32.sin(phi), s)}, A.C{F32.mul(F32.cos(pl), c), F32.mul(F32.sin(pl), c)})}

# U2(phi, lambda) = U3(pi/2, phi, lambda)
def u2(phi: F32, lambda: F32, q: Nat) -> S.Op:
  u3(F32.mul(F32.pi(), 0.5), phi, lambda, q)

def cp(phi: F32, c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.P(phi)}

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
      G.h(off) <> List.append(&2, S.Op, qft.rots(r, off, 1n+off, F32.mul(F32.pi(), 0.5)), qft.go(r, 1n+off))

# k swaps folding the ends inward: (lo, hi), (lo+1, hi-1), ...
def qft.swaps(k: Nat, +lo: Nat, +hi: Nat) -> List<&2, S.Op>:
  match k:
    case 0n:
      Nil{}
    case 1n+j:
      List.append(&2, S.Op, G.swap(lo, hi), qft.swaps(j, 1n+lo, Nat.sub(hi, 1n)))

def qft(+n: Nat) -> List<&2, S.Op>:
  List.append(&2, S.Op, qft.go(n, 0n), qft.swaps(Nat.div(n, 2n), 0n, Nat.sub(n, 1n)))
