import Base
import ./amp.bend as A
import ./sim.bend as S

# Gate constructors, each returning one Op, for the gates that exist in both
# scalar modules; the gates with an angle and the QFT are in rotations.bend.
# Qubit indices count from the root, so qubit 0 is the leftmost printed bit.

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

def cx(c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.X()}

def cz(c: Nat, q: Nat) -> S.Op:
  S.Op{q, [c], A.Z()}

def ccx(c1: Nat, c2: Nat, q: Nat) -> S.Op:
  S.Op{q, [c1, c2], A.X()}


# a two-qubit gate g on the basis |t1 t2> (in the order 00 01 10 11), the
# targets in either depth order, with controls cs
def ctwo.at(lt: Bool, cs: List<&2, Nat>, t1: Nat, t2: Nat, g: S.Gate4) -> S.Op:
  match lt:
    case True{}:
      S.Op4{t1, t2, cs, g}
    case False{}:
      S.Op4{t2, t1, cs, S.Gate4.flip(g)}

def ctwo(cs: List<&2, Nat>, +t1: Nat, +t2: Nat, g: S.Gate4) -> S.Op:
  ctwo.at(Nat.is_lt(t1, t2), cs, t1, t2, g)

def two(t1: Nat, t2: Nat, g: S.Gate4) -> S.Op:
  ctwo(Nil{}, t1, t2, g)

# CNOT as a 4x4, for checking the two-qubit walk against cx
def cx4(c: Nat, q: Nat) -> S.Op:
  two(c, q, S.Gate4{S.Row{A.C.one(), A.C.zero(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.one(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.zero(), A.C.zero(), A.C.one()}, S.Row{A.C.zero(), A.C.zero(), A.C.one(), A.C.zero()}})

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
