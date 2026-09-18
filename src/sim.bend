import Base

# A quantum circuit simulator. The state of n qubits is a perfect binary tree
# of depth n over complex F32 amplitudes: the root splits on qubit 0, its left
# child is qubit 0 = |0>, and the leaves read root to leaf as the bitstrings
# 00..0 to 11..1. A gate is one walk down the tree driven by a per-qubit role
# list; measurement and sampling are folds.

# Amplitudes
# ----------

type C is Data:
  C{re: F32, im: F32}

def C.zero() -> C:
  C{0.0, 0.0}

def C.one() -> C:
  C{1.0, 0.0}

def C.add(x: C, y: C) -> C:
  match x y:
    case C{a, b} C{c, d}:
      C{F32.add(a, c), F32.add(b, d)}

def C.sub(x: C, y: C) -> C:
  match x y:
    case C{a, b} C{c, d}:
      C{F32.sub(a, c), F32.sub(b, d)}

def C.mul(x: C, y: C) -> C:
  match x y:
    case C{+a, +b} C{+c, +d}:
      C{F32.sub(F32.mul(a, c), F32.mul(b, d)), F32.add(F32.mul(a, d), F32.mul(b, c))}

def C.scale(+s: F32, x: C) -> C:
  match x:
    case C{a, b}:
      C{F32.mul(s, a), F32.mul(s, b)}

def C.norm2(x: C) -> F32:
  match x:
    case C{+a, +b}:
      F32.add(F32.mul(a, a), F32.mul(b, b))

# rounded to three decimals, for pinned lines that must not hang on a last bit
def F32.round3(v: F32) -> F32:
  F32.div(F32.round(F32.mul(v, 1000.0)), 1000.0)

def C.round(x: C) -> C:
  match x:
    case C{a, b}:
      C{F32.round3(a), F32.round3(b)}

# re+imi or re-imi; adding 0.0 first turns a negative zero into a plain one
def C.show.im(neg: Bool, b: F32) -> String:
  match neg:
    case False{}:
      "+" ++ F32.show(b)
    case True{}:
      F32.show(b)

def C.show(x: C) -> String:
  match x:
    case C{a, b}:
      +im = F32.add(b, 0.0)
      F32.show(F32.add(a, 0.0)) ++ C.show.im(F32.is_lt(im, 0.0), im) ++ "i"

# Gates
# -----

# the matrix [[a, b], [c, d]]
type Gate is Data:
  Gate{a: C, b: C, c: C, d: C}

# (a x + b y, c x + d y): the leaf of every gate pass
def Gate.apply(g: Gate, +x: C, +y: C) -> C & C:
  match g:
    case Gate{a, b, c, d}:
      (C.add(C.mul(a, x), C.mul(b, y)), C.add(C.mul(c, x), C.mul(d, y)))

# 1/sqrt2, written once and multiplied, never divided
def rh() -> F32:
  0.70710677

def H() -> Gate:
  Gate{C{rh(), 0.0}, C{rh(), 0.0}, C{rh(), 0.0}, C{F32.neg(rh()), 0.0}}

def X() -> Gate:
  Gate{C.zero(), C.one(), C.one(), C.zero()}

def Y() -> Gate:
  Gate{C.zero(), C{0.0, F32.neg(1.0)}, C{0.0, 1.0}, C.zero()}

def Z() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{F32.neg(1.0), 0.0}}

def S() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{0.0, 1.0}}

def Sdg() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{0.0, F32.neg(1.0)}}

def T() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{rh(), rh()}}

def Tdg() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{rh(), F32.neg(rh())}}

# diag(1, e^(i phi))
def P(+phi: F32) -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{F32.cos(phi), F32.sin(phi)}}

# rotations by theta about X, Y and Z, on the half angle
def RX(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, 0.0}, C{0.0, F32.neg(s)}, C{0.0, F32.neg(s)}, C{c, 0.0}}

def RY(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, 0.0}, C{F32.neg(s), 0.0}, C{s, 0.0}, C{c, 0.0}}

def RZ(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, F32.neg(s)}, C.zero(), C.zero(), C{c, s}}

def U(a: C, b: C, c: C, d: C) -> Gate:
  Gate{a, b, c, d}

# The state
# ---------

def Q(n: Nat) -> Type:
  match n:
    case 0n:
      C
    case 1n++p:
      Q(p) & Q(p)

def zeros(n: Nat) -> Q(n):
  match n:
    case 0n:
      C.zero()
    case 1n++p:
      (zeros(p), zeros(p))

def ket0(n: Nat) -> Q(n):
  match n:
    case 0n:
      C.one()
    case 1n++p:
      (ket0(p), zeros(p))

# The walk
# --------

# what a gate does at one qubit, root first; a list that ends early skips the rest
type Role is Data:
  Skip{}
  Ctrl{}
  Targ{}

# Below the target, mix holds the |0> subtree l and the |1> subtree r and hands
# back both new subtrees from one pass. A pair that comes back from a call is
# taken apart by a helper, since a match may only scrutinize a parameter.
def mix.join(-p: Nat, a: Q(p) & Q(p), b: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (l0, r0) = a
  (l1, r1) = b
  ((l0, l1), (r0, r1))

def mix.ctrl(-p: Nat, l0: Q(p), r0: Q(p), m: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p):
  (l1, r1) = m
  ((l0, l1), (r0, r1))

def mix(n: Nat, +rs: List<&2, Role>, +g: Gate, l: Q(n), r: Q(n)) -> Q(n) & Q(n):
  match n rs:
    case 0n _:
      Gate.apply(g, l, r)
    case 1n++p Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix.ctrl(p, l0, r0, mix(p, t, g, l1, r1))
    case 1n++p _:
      (l0, l1) = l
      (r0, r1) = r
      +t = List.tail(&2, Role, rs)
      a b = mix(p, t, g, l0, r0) mix(p, t, g, l1, r1)
      mix.join(p, a, b)

# apply walks the roles down to the target: it forks at Skip, takes the |1>
# branch at Ctrl, and at Targ hands both halves to mix
def apply(n: Nat, +rs: List<&2, Role>, +g: Gate, q: Q(n)) -> Q(n):
  match n rs:
    case 0n _:
      q
    case 1n++p Nil{}:
      q
    case 1n++p Skip{} <> t:
      (l, r) = q
      x y = apply(p, t, g, l) apply(p, t, g, r)
      (x, y)
    case 1n++p Ctrl{} <> t:
      (l, r) = q
      (l, apply(p, t, g, r))
    case 1n++p Targ{} <> t:
      (l, r) = q
      mix(p, t, g, l, r)

# Roles are built, never written: Targ at the target, Ctrl at each control,
# Skip elsewhere, one entry per qubit.

# Ctrl when index 0 is a control
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

# the controls one level down: index 0 gone, the rest shifted by one
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

# one gate of a circuit: g on the target t with the controls cs, indices from the root
type Op is Data:
  Op{t: Nat, cs: List<&2, Nat>, g: Gate}

# a circuit is a list of ops, applied first to last
def run(+n: Nat, ops: List<&2, Op>, q: Q(n)) -> Q(n):
  match ops:
    case Nil{}:
      q
    case Op{t, cs, g} <> rest:
      run(n, rest, apply(n, roles(n, t, cs), g, q))

# Readout
# -------

# the amplitudes root to leaf, each printed by f
def show.by(~f: C -> String, n: Nat, q: Q(n)) -> String:
  match n:
    case 0n:
      f(q)
    case 1n++p:
      (l, r) = q
      show.by(~f, p, l) ++ " " ++ show.by(~f, p, r)

def show(n: Nat, q: Q(n)) -> String:
  show.by(~C.show, n, q)

# rounded for display, so a pinned line does not hang on the last bit of a cos
def show3(n: Nat, q: Q(n)) -> String:
  show.by(~(x => C.show(C.round(x))), n, q)

# every amplitude of a within sqrt(eps2) of its counterpart in b
def near(n: Nat, +eps2: F32, a: Q(n), b: Q(n)) -> Bool:
  match n:
    case 0n:
      F32.is_lt(C.norm2(C.sub(a, b)), eps2)
    case 1n++p:
      (a0, a1) = a
      (b0, b1) = b
      x y = near(p, eps2, a0, b0) near(p, eps2, a1, b1)
      x && y

# Measurement
# -----------

# |q|^2, consuming the state; the parallel fold is pairwise summation
def norm2(n: Nat, q: Q(n)) -> F32:
  match n:
    case 0n:
      C.norm2(q)
    case 1n++p:
      (l, r) = q
      a b = norm2(p, l) norm2(p, r)
      F32.add(a, b)

# |q|^2 beside the rebuilt state, since the state is linear
def weigh.join(-p: Nat, a: F32 & Q(p), b: F32 & Q(p)) -> F32 & Q(1n+p):
  (x, l) = a
  (y, r) = b
  (F32.add(x, y), (l, r))

def weigh(n: Nat, q: Q(n)) -> F32 & Q(n):
  match n:
    case 0n:
      +x = {q : C}
      (C.norm2(x), x)
    case 1n++p:
      (l, r) = q
      a b = weigh(p, l) weigh(p, r)
      weigh.join(p, a, b)

# the probability that qubit k reads 1, beside the state
def prob1(n: Nat, k: Nat, q: Q(n)) -> F32 & Q(n):
  match n k:
    case 0n _:
      (0.0, q)
    case 1n++p 0n:
      (l, r) = q
      weigh.join(p, (0.0, l), weigh(p, r))
    case 1n++p 1n++j:
      (l, r) = q
      a b = prob1(p, j, l) prob1(p, j, r)
      weigh.join(p, a, b)

# the collapse of qubit k onto b: the other branch at depth k becomes zeros
def project.at(p: Nat, b: Bool, l: Q(p), r: Q(p)) -> Q(1n+p):
  match b:
    case False{}:
      (l, zeros(p))
    case True{}:
      (zeros(p), r)

def project(n: Nat, k: Nat, +b: Bool, q: Q(n)) -> Q(n):
  match n k:
    case 0n _:
      q
    case 1n++p 0n:
      (l, r) = q
      project.at(p, b, l, r)
    case 1n++p 1n++j:
      (l, r) = q
      x y = project(p, j, b, l) project(p, j, b, r)
      (x, y)

def rescale(n: Nat, +s: F32, q: Q(n)) -> Q(n):
  match n:
    case 0n:
      C.scale(s, q)
    case 1n++p:
      (l, r) = q
      a b = rescale(p, s, l) rescale(p, s, r)
      (a, b)

# measure qubit k with the uniform u: 1 when u < p1; the survivor is scaled by
# 1/sqrt(its probability), here and nowhere else
def measure.fin(+n: Nat, k: Nat, u: F32, r: F32 & Q(n)) -> Bool & Q(n):
  (+p1, q) = r
  +b = F32.is_lt(u, p1)
  (b, rescale(n, F32.div(1.0, F32.sqrt(Bool.pick(F32, b, p1, F32.sub(1.0, p1)))), project(n, k, b, q)))

def measure(+n: Nat, +k: Nat, u: F32, q: Q(n)) -> Bool & Q(n):
  measure.fin(n, k, u, prob1(n, k, q))

# <Z_k> = 1 - 2 p1, beside the state
def expect_z.fin(-n: Nat, r: F32 & Q(n)) -> F32 & Q(n):
  (p1, q) = r
  (F32.sub(1.0, F32.mul(2.0, p1)), q)

def expect_z(+n: Nat, k: Nat, q: Q(n)) -> F32 & Q(n):
  expect_z.fin(n, prob1(n, k, q))

# Sampling
# --------

# xorshift32; a seed of 0 would stay 0
def xs32(+x: U32) -> U32:
  +a = (x .^. (x << 13n) : U32)
  +b = (a .^. (a >> 17n) : U32)
  (b .^. (b << 5n) : U32)

# the hash-prospector finalizer, in decimal: xorshift32's raw output is linear
# in its state, and this breaks that
def mix32(+x: U32) -> U32:
  +a = (x .^. (x >> 16n) : U32)
  +b = (a * 569420461 : U32)
  +c = (b .^. (b >> 15n) : U32)
  +d = (c * 3545902487 : U32)
  (d .^. (d >> 15n) : U32)

# a uniform in [0, 1) from the top 24 bits; both steps are exact
def unif(x: U32) -> F32:
  F32.mul(U32.to_f32((mix32(x) >> 8n : U32)), 5.9604645e-8)

# the default seed, fixed so histograms are reproducible
def seed() -> U32:
  2463534242

# k uniforms from the seed s. Every walk over the shots is a tail call, so the
# JS lane's machine stack takes any count.
def unifs.go(k: Nat, s: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match k:
    case 0n:
      acc
    case 1n+j:
      +x = xs32(s)
      unifs.go(j, x, unif(x) <> acc)

def unifs(k: Nat, s: U32) -> List<&2, F32>:
  unifs.go(k, s, Nil{})

def tally(us: List<&2, F32>, acc: Nat) -> Nat:
  match us:
    case Nil{}:
      acc
    case u <> rest:
      tally(rest, 1n+acc)

# the probability tree: at each node the fraction of the weight in its |0> half
def W(n: Nat) -> Type:
  match n:
    case 0n:
      Unit
    case 1n++p:
      F32 & W(p) & W(p)

# sums consumes the state; the total weight comes back beside the tree
def sums.join(-p: Nat, a: F32 & W(p), b: F32 & W(p)) -> F32 & W(1n+p):
  (+x, l) = a
  (y, r) = b
  +t = F32.add(x, y)
  (t, (F32.div(x, t), (l, r)))

def sums(n: Nat, q: Q(n)) -> F32 & W(n):
  match n:
    case 0n:
      (C.norm2(q), Unit{})
    case 1n++p:
      (l, r) = q
      a b = sums(p, l) sums(p, r)
      sums.join(p, a, b)

# a histogram bin: a bitstring and how many shots landed on it
type Bin is Data:
  Bin{bits: String, count: Nat}

# the uniforms on one side of c, rescaled back to [0, 1): below c on the low
# side, at or above it on the high side
def side.put(+c: F32, u: F32, low: Bool, hit: Bool, acc: List<&2, F32>) -> List<&2, F32>:
  match low hit:
    case True{} True{}:
      F32.div(u, c) <> acc
    case False{} False{}:
      F32.div(F32.sub(u, c), F32.sub(1.0, c)) <> acc
    case _ _:
      acc

def side.go(+c: F32, +low: Bool, +us: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match us:
    case Nil{}:
      acc
    case u <> rest:
      side.go(c, low, rest, side.put(c, u, low, F32.is_lt(u, c), acc))

def side(+c: F32, low: Bool, us: List<&2, F32>) -> List<&2, F32>:
  side.go(c, low, us, Nil{})

# route the uniforms down the tree, pruning empty nodes; each populated leaf is
# one Bin, and the bins come back in bitstring order
def shots(n: Nat, +bits: String, +us: List<&2, F32>, w: W(n)) -> List<&2, Bin>:
  match n us:
    case _ Nil{}:
      Nil{}
    case 0n _:
      [Bin{bits, tally(us, 0n)}]
    case 1n++p _:
      (+c, lr) = w
      (l, r) = lr
      a b = shots(p, bits ++ "0", side(c, True{}, us), l) shots(p, bits ++ "1", side(c, False{}, us), r)
      List.append(&2, Bin, a, b)

# k shots of q from the seed s; a U32 count, since a large Nat literal overflows the checker
def sample.fin(n: Nat, us: List<&2, F32>, r: F32 & W(n)) -> List<&2, Bin>:
  (t, w) = r
  shots(n, "", us, w)

def sample(+n: Nat, k: U32, s: U32, q: Q(n)) -> List<&2, Bin>:
  sample.fin(n, unifs(U32.to_nat(k), s), sums(n, q))

# one "bitstring count" line per bin
def show_hist(bins: List<&2, Bin>) -> String:
  match bins:
    case Nil{}:
      ""
    case Bin{bits, count} <> Nil{}:
      bits ++ " " ++ Nat.show(count)
    case Bin{bits, count} <> rest:
      bits ++ " " ++ Nat.show(count) ++ "\n" ++ show_hist(rest)
