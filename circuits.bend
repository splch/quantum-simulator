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
