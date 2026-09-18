import Base
import ./amp.bend as A

# The state of n qubits is a perfect binary tree of depth n over amplitudes.
# The root splits on qubit 0 and the left child is qubit 0 = |0>, so the
# leaves read root to leaf as the bitstrings 00..0, 00..1, ..., 11..1.
def Q(n: Nat) -> Type:
  match n:
    case 0n:
      A.C
    case 1n++p:
      Q(p) & Q(p)

def zeros(n: Nat) -> Q(n):
  match n:
    case 0n:
      A.C.zero()
    case 1n++p:
      (zeros(p), zeros(p))

# |0..0>
def ket0(n: Nat) -> Q(n):
  match n:
    case 0n:
      A.C.one()
    case 1n++p:
      (ket0(p), zeros(p))

# what a gate does at one qubit, listed root first; a list that ends early
# skips the remaining qubits
type Role is Data:
  Skip{}
  Ctrl{}
  Targ{}

# Below the target, mix holds the |0> subtree l and the |1> subtree r and
# returns both new subtrees from one pass, so nothing is cloned. A pair that
# comes back from a call is taken apart by a helper, since a destructuring let
# is a match and a match may only scrutinize a parameter.
def mix.join(-p: Nat, a: Q(p) & Q(p), b: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (l0, r0) = a
  (l1, r1) = b
  ((l0, l1), (r0, r1))

# a control below the target: the |0> halves pass through untouched
def mix.ctrl(-p: Nat, l0: Q(p), r0: Q(p), m: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (l1, r1) = m
  ((l0, l1), (r0, r1))

def mix(n: Nat, +rs: List<&2, Role>, +g: A.Gate, l: Q(n), r: Q(n)) -> Q(n) & Q(n):
  match n rs:
    case 0n _:
      A.Gate.apply(g, l, r)
    case 1n++p Nil{}:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, Nil{}, g, l0, r0) mix(p, Nil{}, g, l1, r1)
      mix.join(p, a, b)
    case 1n++p Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix.ctrl(p, l0, r0, mix(p, t, g, l1, r1))
    case 1n++p _ <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, t, g, l0, r0) mix(p, t, g, l1, r1)
      mix.join(p, a, b)

# Above the target, apply walks down the roles: it forks at Skip, takes only
# the |1> branch at Ctrl, and hands both halves to mix at Targ.
def apply(n: Nat, +rs: List<&2, Role>, +g: A.Gate, q: Q(n)) -> Q(n):
  match n rs:
    case 0n _:
      q
    case 1n++p Nil{}:
      q
    case 1n++p Skip{} <> t:
      (l, r) = q
      a b = apply(p, t, g, l) apply(p, t, g, r)
      (a, b)
    case 1n++p Ctrl{} <> t:
      (l, r) = q
      (l, apply(p, t, g, r))
    case 1n++p Targ{} <> t:
      (l, r) = q
      mix(p, t, g, l, r)

# Role lists are built, never written by hand: roles(n, t, cs) holds exactly
# one Targ, at index t, a Ctrl at each control in cs, and Skip elsewhere.

# Ctrl when index 0 is among the controls, else Skip
def here(cs: List<&2, Nat>) -> Role:
  match cs:
    case Nil{}:
      Skip{}
    case c <> rest:
      match c:
        case 0n:
          Ctrl{}
        case 1n+k:
          here(rest)

# the controls seen from one level down: index 0 is gone, the rest shift by one
def down(cs: List<&2, Nat>) -> List<&2, Nat>:
  match cs:
    case Nil{}:
      Nil{}
    case c <> rest:
      match c:
        case 0n:
          down(rest)
        case 1n+k:
          k <> down(rest)

# the roles below the target
def ctrls(n: Nat, +cs: List<&2, Nat>) -> List<&2, Role>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      here(cs) <> ctrls(p, down(cs))

def roles(n: Nat, t: Nat, +cs: List<&2, Nat>) -> List<&2, Role>:
  match n t:
    case 0n _:
      Nil{}
    case 1n+p 0n:
      Targ{} <> ctrls(p, down(cs))
    case 1n+p 1n+u:
      here(cs) <> roles(p, u, down(cs))

# one gate of a circuit: g on target t with controls cs, indices from the root
type Op is Data:
  Op{t: Nat, cs: List<&2, Nat>, g: A.Gate}

# a circuit is a list of ops, applied first to last
def run(+n: Nat, ops: List<&2, Op>, q: Q(n)) -> Q(n):
  match ops:
    case Nil{}:
      q
    case Op{t, cs, g} <> rest:
      run(n, rest, apply(n, roles(n, t, cs), g, q))

# the amplitudes root to leaf, separated by spaces
def show(n: Nat, q: Q(n)) -> String:
  match n:
    case 0n:
      A.C.show(q)
    case 1n++p:
      (l, r) = q
      show(p, l) ++ " " ++ show(p, r)

# every amplitude of a is within sqrt(eps2) of its counterpart in b
def near(n: Nat, +eps2: F32, a: Q(n), b: Q(n)) -> Bool:
  match n:
    case 0n:
      F32.is_lt(A.C.norm2(A.C.sub(a, b)), eps2)
    case 1n++p:
      (a0, a1) = a
      (b0, b1) = b
      x y = near(p, eps2, a0, b0) near(p, eps2, a1, b1)
      Bool.and(x, y)
