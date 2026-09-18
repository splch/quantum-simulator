import Base

# a complex amplitude
type C is Data:
  C{re: F32, im: F32}

def C.add(x: C, y: C) -> C:
  match x y:
    case C{a, b} C{c, d}:
      C{F32.add(a, c), F32.add(b, d)}

def C.mul(x: C, y: C) -> C:
  match x y:
    case C{+a, +b} C{+c, +d}:
      C{F32.sub(F32.mul(a, c), F32.mul(b, d)), F32.add(F32.mul(a, d), F32.mul(b, c))}

def C.norm2(x: C) -> F32:
  match x:
    case C{+a, +b}:
      F32.add(F32.mul(a, a), F32.mul(b, b))

def C.show(x: C) -> String:
  match x:
    case C{a, b}:
      F32.show(a) ++ "+" ++ F32.show(b) ++ "i"

# the state of n qubits: a perfect binary tree of depth n over C
def Q(n: Nat) -> Type:
  match n:
    case 0n:
      C
    case 1n++p:
      Q(p) & Q(p)

def zeros(n: Nat) -> Q(n):
  match n:
    case 0n:
      C{0.0, 0.0}
    case 1n++p:
      (zeros(p), zeros(p))

def ket0(n: Nat) -> Q(n):
  match n:
    case 0n:
      C{1.0, 0.0}
    case 1n++p:
      (ket0(p), zeros(p))

type Role is Data:
  Skip{}
  Ctrl{}
  Targ{}

type Gate is Data:
  Gate{a: C, b: C, c: C, d: C}

# the leaf of mix: (a*x + b*y, c*x + d*y)
def mix.leaf(g: Gate, +x: C, +y: C) -> C & C:
  match g:
    case Gate{a, b, c, d}:
      (C.add(C.mul(a, x), C.mul(b, y)), C.add(C.mul(c, x), C.mul(d, y)))

# join of the two halves: a destructuring let is a match, and a match may
# only scrutinize a parameter, so the pair results are passed in
def mix.join(-p: Nat, a: Q(p) & Q(p), b: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (nl0, nr0) = a
  (nl1, nr1) = b
  ((nl0, nl1), (nr0, nr1))

# a control qubit: only the 1-halves were mixed
def mix.ctrl(-p: Nat, l0: Q(p), r0: Q(p), nn: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (nl1, nr1) = nn
  ((l0, nl1), (r0, nr1))

# l and r are the two halves under the target qubit; rs are the roles below it
def mix(n: Nat, +rs: List<&2, Role>, +g: Gate, l: Q(n), r: Q(n)) -> Q(n) & Q(n):
  match n rs:
    case 0n _:
      mix.leaf(g, l, r)
    case 1n++p Nil{}:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, Nil{}, g, l0, r0) mix(p, Nil{}, g, l1, r1)
      mix.join(p, a, b)
    case 1n++p Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix.ctrl(p, l0, r0, mix(p, t, g, l1, r1))
    case 1n++p Skip{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, t, g, l0, r0) mix(p, t, g, l1, r1)
      mix.join(p, a, b)
    case 1n++p Targ{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, t, g, l0, r0) mix(p, t, g, l1, r1)
      mix.join(p, a, b)

def apply(n: Nat, +rs: List<&2, Role>, +g: Gate, q: Q(n)) -> Q(n):
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

def show(n: Nat, q: Q(n)) -> String:
  match n:
    case 0n:
      C.show(q)
    case 1n++p:
      (l, r) = q
      show(p, l) ++ " " ++ show(p, r)

# clone a state: at a leaf, l : Q(0n) is C, but the + let needs the annotation
def twice.join(-p: Nat, a: Q(p) & Q(p), b: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (a0, a1) = a
  (b0, b1) = b
  ((a0, b0), (a1, b1))

def twice(n: Nat, l: Q(n)) -> Q(n) & Q(n):
  match n:
    case 0n:
      +x = {l : C}
      (x, x)
    case 1n++p:
      (l0, l1) = l
      a b = twice(p, l0) twice(p, l1)
      twice.join(p, a, b)

def rh() -> F32:
  0.70710677

def H() -> Gate:
  Gate{C{rh(), 0.0}, C{rh(), 0.0}, C{rh(), 0.0}, C{F32.neg(rh()), 0.0}}

def X() -> Gate:
  Gate{C{0.0, 0.0}, C{1.0, 0.0}, C{1.0, 0.0}, C{0.0, 0.0}}

def main() -> IO(Unit):
  q0 = ket0(2n)
  q1 = apply(2n, [Targ{}, Skip{}], H(), q0)
  q2 = apply(2n, [Ctrl{}, Targ{}], X(), q1)
  IO.print(show(2n, q2))
