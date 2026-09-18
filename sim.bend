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

# Two-qubit gates
# ---------------
# A 4x4 matrix on the targets t1 and t2, t1 the shallower, acting on the
# basis |t1 t2> in the order 00 01 10 11. apply4 walks down to t1, mix4a
# carries its two subtrees down to t2 together, and mix4b carries the four
# subtrees below both targets down to the leaves, where the matrix acts.
# The entries are scalars, so the exact build has exact two-qubit gates.

type Row is Data:
  Row{a: A.C, b: A.C, c: A.C, d: A.C}

type Gate4 is Data:
  Gate4{r0: Row, r1: Row, r2: Row, r3: Row}

# the dot product of a row with the four amplitudes, in canonical form
def Row.dot(r: Row, +x: A.C, +y: A.C, +z: A.C, +w: A.C) -> A.C:
  match r:
    case Row{a, b, c, d}:
      A.C.canon(A.C.add(A.C.add(A.C.mul(a, x), A.C.mul(b, y)), A.C.add(A.C.mul(c, z), A.C.mul(d, w))))

# the matrix on the four amplitudes: ((new 00, new 01), (new 10, new 11))
def Gate4.apply(g: Gate4, +x: A.C, +y: A.C, +z: A.C, +w: A.C) -> (A.C & A.C) & (A.C & A.C):
  match g:
    case Gate4{r0, r1, r2, r3}:
      ((Row.dot(r0, x, y, z, w), Row.dot(r1, x, y, z, w)), (Row.dot(r2, x, y, z, w), Row.dot(r3, x, y, z, w)))

# the same matrix with its two qubits exchanged: basis states 01 and 10 swap
def Row.flip(r: Row) -> Row:
  match r:
    case Row{a, b, c, d}:
      Row{a, c, b, d}

def Gate4.flip(g: Gate4) -> Gate4:
  match g:
    case Gate4{r0, r1, r2, r3}:
      Gate4{Row.flip(r0), Row.flip(r2), Row.flip(r1), Row.flip(r3)}

# below both targets: the four subtrees x y z w (basis 00 01 10 11) walk to
# the leaves together; the result is ((x', y'), (z', w')), the two subtrees
# of the shallower target
def mix4b.join(-p: Nat, u: Q(1n+p) & Q(1n+p), v: Q(1n+p) & Q(1n+p)) -> Q(2n+p) & Q(2n+p):
  (l0, r0) = u
  (x0, y0) = l0
  (z0, w0) = r0
  (l1, r1) = v
  (x1, y1) = l1
  (z1, w1) = r1
  (((x0, x1), (y0, y1)), ((z0, z1), (w0, w1)))

# a control below both targets: the |0> halves pass through
def mix4b.ctrl(-p: Nat, x0: Q(p), y0: Q(p), z0: Q(p), w0: Q(p), v: Q(1n+p) & Q(1n+p)) -> Q(2n+p) & Q(2n+p):
  (l1, r1) = v
  (x1, y1) = l1
  (z1, w1) = r1
  (((x0, x1), (y0, y1)), ((z0, z1), (w0, w1)))

def mix4b(n: Nat, +rs: List<&2, Role>, +g: Gate4, x: Q(n), y: Q(n), z: Q(n), w: Q(n)) -> Q(1n+n) & Q(1n+n):
  match n rs:
    case 0n _:
      Gate4.apply(g, x, y, z, w)
    case 1n++p Nil{}:
      (x0, x1) = x
      (y0, y1) = y
      (z0, z1) = z
      (w0, w1) = w
      u v = mix4b(p, Nil{}, g, x0, y0, z0, w0) mix4b(p, Nil{}, g, x1, y1, z1, w1)
      mix4b.join(p, u, v)
    case 1n++p Ctrl{} <> t:
      (x0, x1) = x
      (y0, y1) = y
      (z0, z1) = z
      (w0, w1) = w
      mix4b.ctrl(p, x0, y0, z0, w0, mix4b(p, t, g, x1, y1, z1, w1))
    case 1n++p _ <> t:
      (x0, x1) = x
      (y0, y1) = y
      (z0, z1) = z
      (w0, w1) = w
      u v = mix4b(p, t, g, x0, y0, z0, w0) mix4b(p, t, g, x1, y1, z1, w1)
      mix4b.join(p, u, v)

# between the targets: the two subtrees of the shallower target walk down to
# the deeper one together; without a second Targ the gate does nothing
def mix4a(n: Nat, +rs: List<&2, Role>, +g: Gate4, l: Q(n), r: Q(n)) -> Q(n) & Q(n):
  match n rs:
    case 0n _:
      (l, r)
    case 1n++p Nil{}:
      (l, r)
    case 1n++p Targ{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix4b(p, t, g, l0, l1, r0, r1)
    case 1n++p Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix.ctrl(p, l0, r0, mix4a(p, t, g, l1, r1))
    case 1n++p Skip{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix4a(p, t, g, l0, r0) mix4a(p, t, g, l1, r1)
      mix.join(p, a, b)

# above the shallower target, as apply
def apply4(n: Nat, +rs: List<&2, Role>, +g: Gate4, q: Q(n)) -> Q(n):
  match n rs:
    case 0n _:
      q
    case 1n++p Nil{}:
      q
    case 1n++p Skip{} <> t:
      (l, r) = q
      a b = apply4(p, t, g, l) apply4(p, t, g, r)
      (a, b)
    case 1n++p Ctrl{} <> t:
      (l, r) = q
      (l, apply4(p, t, g, r))
    case 1n++p Targ{} <> t:
      (l, r) = q
      mix4a(p, t, g, l, r)

# the roles of a two-qubit gate: Targ at t1 and at t2 (t1 the shallower),
# Ctrl at the controls, Skip elsewhere
def roles4(n: Nat, t1: Nat, t2: Nat, +cs: List<&2, Nat>) -> List<&2, Role>:
  match n t1:
    case 0n _:
      Nil{}
    case 1n+p 0n:
      Targ{} <> roles(p, Nat.sub(t2, 1n), down(cs))
    case 1n+p 1n+u:
      here(cs) <> roles4(p, u, Nat.sub(t2, 1n), down(cs))

# one gate of a circuit: g on target t with controls cs, or a two-qubit g on
# the targets t1 and t2 (t1 the shallower); indices count from the root
type Op is Data:
  Op{t: Nat, cs: List<&2, Nat>, g: A.Gate}
  Op4{t1: Nat, t2: Nat, cs: List<&2, Nat>, g: Gate4}

# a circuit is a list of ops, applied first to last
def run(+n: Nat, ops: List<&2, Op>, q: Q(n)) -> Q(n):
  match ops:
    case Nil{}:
      q
    case Op{t, cs, g} <> rest:
      run(n, rest, apply(n, roles(n, t, cs), g, q))
    case Op4{t1, t2, cs, g} <> rest:
      run(n, rest, apply4(n, roles4(n, t1, t2, cs), g, q))

# the amplitudes root to leaf, separated by spaces
def show(n: Nat, q: Q(n)) -> String:
  match n:
    case 0n:
      A.C.show(q)
    case 1n++p:
      (l, r) = q
      show(p, l) ++ " " ++ show(p, r)

# the amplitudes rounded for display (three decimals with F32 amplitudes)
def show3(n: Nat, q: Q(n)) -> String:
  match n:
    case 0n:
      A.C.show(A.C.round(q))
    case 1n++p:
      (l, r) = q
      show3(p, l) ++ " " ++ show3(p, r)

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

# Measurement
# -----------

# |q|^2, consuming the state; the parallel fold is pairwise summation
def norm2(n: Nat, q: Q(n)) -> F32:
  match n:
    case 0n:
      A.C.norm2(q)
    case 1n++p:
      (l, r) = q
      a b = norm2(p, l) norm2(p, r)
      F32.add(a, b)

# The state is linear, so a reduction that must keep it hands it back beside
# the value. weigh is |q|^2 beside the rebuilt state.
def weigh.join(-p: Nat, a: F32 & Q(p), b: F32 & Q(p)) -> F32 & Q(1n+p):
  (x, l) = a
  (y, r) = b
  (F32.add(x, y), (l, r))

def weigh(n: Nat, q: Q(n)) -> F32 & Q(n):
  match n:
    case 0n:
      +x = {q : A.C}
      (A.C.norm2(x), x)
    case 1n++p:
      (l, r) = q
      a b = weigh(p, l) weigh(p, r)
      weigh.join(p, a, b)

# the probability that qubit k reads 1, beside the state
def prob1.at(-p: Nat, l: Q(p), b: F32 & Q(p)) -> F32 & Q(1n+p):
  (y, r) = b
  (y, (l, r))

def prob1(n: Nat, k: Nat, q: Q(n)) -> F32 & Q(n):
  match n k:
    case 0n _:
      (0.0, q)
    case 1n++p 0n:
      (l, r) = q
      prob1.at(p, l, weigh(p, r))
    case 1n++p 1n++j:
      (l, r) = q
      a b = prob1(p, j, l) prob1(p, j, r)
      weigh.join(p, a, b)

# The collapse of qubit k onto the outcome b: the branch for the other outcome
# becomes zeros at depth k. Nothing is renormalized here, so laws about the
# shape of the result stay float-free.
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

# every amplitude multiplied by s
def rescale(n: Nat, +s: F32, q: Q(n)) -> Q(n):
  match n:
    case 0n:
      A.C.scale(s, q)
    case 1n++p:
      (l, r) = q
      a b = rescale(p, s, l) rescale(p, s, r)
      (a, b)

# the probability of the outcome b when qubit k reads 1 with probability p1
def prob_of(b: Bool, +p1: F32) -> F32:
  match b:
    case False{}:
      F32.sub(1.0, p1)
    case True{}:
      p1

# Measure qubit k, driven by the uniform u: the outcome is 1 when u < p1. The
# survivor is renormalized by 1/sqrt(its probability), here and nowhere else.
def measure.fin(+n: Nat, k: Nat, u: F32, r: F32 & Q(n)) -> Bool & Q(n):
  (+p1, q) = r
  +b = F32.is_lt(u, p1)
  (b, rescale(n, F32.div(1.0, F32.sqrt(prob_of(b, p1))), project(n, k, b, q)))

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

# xorshift32, the step of the PRNG; a seed of 0 would stay 0
def xs32(+x: U32) -> U32:
  +a = (x .^. (x << 13n) : U32)
  +b = (a .^. (a >> 17n) : U32)
  (b .^. (b << 5n) : U32)

# The hash-prospector finalizer (16, 0x21f0aaad, 15, 0xd35a2d97, 15), in
# decimal since there are no hex literals: the raw output of xorshift32 is a
# linear function of its state, and the finalizer breaks that. Over 300 seeds
# the raw stream already passed chi-square tests at 4096 draws; this is the
# standard precaution, not a repair.
def mix32(+x: U32) -> U32:
  +a = (x .^. (x >> 16n) : U32)
  +b = (a * 569420461 : U32)
  +c = (b .^. (b >> 15n) : U32)
  +d = (c * 3545902487 : U32)
  (d .^. (d >> 15n) : U32)

# a uniform in [0, 1) from the top 24 bits of the finalized x; both steps are exact
def unif(x: U32) -> F32:
  F32.mul(U32.to_f32((mix32(x) >> 8n : U32)), 5.9604645e-8)

# the default seed, fixed so that histograms are reproducible
def seed() -> U32:
  2463534242

# k uniforms from the seed s. Every walk over the shots is a tail call, so the
# JS backend, which uses the machine stack, takes any shot count.
def unifs.go(k: Nat, s: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match k:
    case 0n:
      acc
    case 1n+j:
      +x = xs32(s)
      unifs.go(j, x, unif(x) <> acc)

def unifs(k: Nat, s: U32) -> List<&2, F32>:
  unifs.go(k, s, Nil{})

# how many uniforms
def tally(us: List<&2, F32>, acc: Nat) -> Nat:
  match us:
    case Nil{}:
      acc
    case u <> rest:
      tally(rest, 1n+acc)

# The probability tree for sampling: at each node the fraction of the
# subtree's weight that lies in its |0> half, and nothing at the leaves. It is
# Data, spelled with Sigma since a plain pair is always Type, so that a proof
# may name a subtree twice; the reference counts this costs are paid once per
# sampling call.
def W(n: Nat) -> Data:
  match n:
    case 0n:
      Unit
    case 1n++p:
      Sigma<&2, &2, F32, _ => Sigma<&2, &2, W(p), _ => W(p)>>

# sums consumes the state and returns its total weight beside the tree
def sums.join(-p: Nat, a: F32 & W(p), b: F32 & W(p)) -> F32 & W(1n+p):
  (+x, l) = a
  (y, r) = b
  +t = F32.add(x, y)
  (t, (F32.div(x, t), (l, r)))

def sums(n: Nat, q: Q(n)) -> F32 & W(n):
  match n:
    case 0n:
      (A.C.norm2(q), Unit{})
    case 1n++p:
      (l, r) = q
      a b = sums(p, l) sums(p, r)
      sums.join(p, a, b)

# a histogram bin: a bitstring and how many shots landed on it
type Bin is Data:
  Bin{bits: String, count: Nat}

# the uniforms below c, rescaled to [0, 1)
def lows.put(c: F32, u: F32, hit: Bool, acc: List<&2, F32>) -> List<&2, F32>:
  match hit:
    case False{}:
      acc
    case True{}:
      F32.div(u, c) <> acc

def lows.go(+c: F32, +us: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match us:
    case Nil{}:
      acc
    case u <> rest:
      lows.go(c, rest, lows.put(c, u, F32.is_lt(u, c), acc))

def lows(+c: F32, us: List<&2, F32>) -> List<&2, F32>:
  lows.go(c, us, Nil{})

# the uniforms at or above c, rescaled to [0, 1)
def highs.put(+c: F32, u: F32, hit: Bool, acc: List<&2, F32>) -> List<&2, F32>:
  match hit:
    case False{}:
      F32.div(F32.sub(u, c), F32.sub(1.0, c)) <> acc
    case True{}:
      acc

def highs.go(+c: F32, +us: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match us:
    case Nil{}:
      acc
    case u <> rest:
      highs.go(c, rest, highs.put(c, u, F32.is_lt(u, c), acc))

def highs(+c: F32, us: List<&2, F32>) -> List<&2, F32>:
  highs.go(c, us, Nil{})

# Route the uniforms down the probability tree: at each node those below the
# node's fraction go left and the rest right, each side rescaled to [0, 1),
# and a node whose list is empty is pruned. Every populated leaf yields one
# Bin, and the bins come back in bitstring order.
def shots(n: Nat, +bits: String, +us: List<&2, F32>, w: W(n)) -> List<&2, Bin>:
  match n us:
    case _ Nil{}:
      Nil{}
    case 0n _:
      [Bin{bits, tally(us, 0n)}]
    case 1n++p _:
      (+c, lr) = w
      (l, r) = lr
      a b = shots(p, bits ++ "0", lows(c, us), l) shots(p, bits ++ "1", highs(c, us), r)
      List.append(&2, Bin, a, b)

# k shots of q from the seed s, as a histogram in bitstring order. The count
# is a U32 because a Nat literal past a few thousand overflows the checker.
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
