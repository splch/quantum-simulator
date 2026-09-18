import Base
import ./amp.bend as A
import ./sim.bend as S

# The flat-leaf hybrid. QF(m) is a tree of depth m whose leaves are blocks of
# 2^lb amplitudes stored as 2^(lb+1) F32s in one Array, re at 2i and im at
# 2i+1, so a state of n = m + lb qubits costs 8 bytes per amplitude against
# the tree's 32. A gate on a qubit above the blocks walks the tree as
# sim.bend does and, where sim.bend would touch two amplitudes, runs an
# elementwise loop over two blocks; a gate on a qubit inside the blocks is a
# loop over each block with the qubit as a bit of the index and the controls
# as a mask. Blocks run in parallel across cores; inside a block the loop is
# sequential. Two-qubit gates, measurement and sampling go through to_tree
# and the tree code.

def QF(m: Nat) -> Type:
  match m:
    case 0n:
      Array<F32>
    case 1n++p:
      QF(p) & QF(p)

# Blocks
# ------

# 2^lb zero amplitudes
def zeros_blk(lb: Nat) -> Array<F32>:
  Array.new(F32, 1n+lb, 0.0)

def zerosf(m: Nat, +lb: Nat) -> QF(m):
  match m:
    case 0n:
      zeros_blk(lb)
    case 1n++p:
      (zerosf(p, lb), zerosf(p, lb))

# |0..0>
def ketf(m: Nat, +lb: Nat) -> QF(m):
  match m:
    case 0n:
      Array.set(F32, zeros_blk(lb), 0, 1.0)
    case 1n++p:
      (ketf(p, lb), zerosf(p, lb))

# the gate on the amplitudes at 2i, 2i+1 (x) and 2j, 2j+1 (y) of one block:
# four reads threading the array, the 2x2 product, four writes
def put2(a: Array<F32>, +j: U32, ny: A.C) -> Array<F32>:
  match ny:
    case A.C{r, i}:
      Array.set(F32, Array.set(F32, a, (2 * j : U32), r), (2 * j + 1 : U32), i)

def put(a: Array<F32>, +i: U32, +j: U32, xy: A.C & A.C) -> Array<F32>:
  (nx, ny) = xy
  match nx:
    case A.C{r, im}:
      put2(Array.set(F32, Array.set(F32, a, (2 * i : U32), r), (2 * i + 1 : U32), im), j, ny)

def bfly.4(r: Array<F32> & F32, +g: A.Gate, +i: U32, +j: U32, xr: F32, xi: F32, yr: F32) -> Array<F32>:
  (a, yi) = r
  put(a, i, j, A.Gate.apply(g, A.C{xr, xi}, A.C{yr, yi}))

def bfly.3(r: Array<F32> & F32, +g: A.Gate, +i: U32, +j: U32, xr: F32, xi: F32) -> Array<F32>:
  (a, yr) = r
  bfly.4(Array.get(F32, a, (2 * j + 1 : U32)), g, i, j, xr, xi, yr)

def bfly.2(r: Array<F32> & F32, +g: A.Gate, +i: U32, +j: U32, xr: F32) -> Array<F32>:
  (a, xi) = r
  bfly.3(Array.get(F32, a, (2 * j : U32)), g, i, j, xr, xi)

def bfly.1(r: Array<F32> & F32, +g: A.Gate, +i: U32, +j: U32) -> Array<F32>:
  (a, xr) = r
  bfly.2(Array.get(F32, a, (2 * i + 1 : U32)), g, i, j, xr)

def bfly(g: A.Gate, a: Array<F32>, +i: U32, j: U32) -> Array<F32>:
  bfly.1(Array.get(F32, a, (2 * i : U32)), g, i, j)

def pair.at(go: Bool, g: A.Gate, a: Array<F32>, i: U32, j: U32) -> Array<F32>:
  match go:
    case True{}:
      bfly(g, a, i, j)
    case False{}:
      a

# the gate on the qubit at bit tbit of every index of one block, where the
# control bits in mask are set; k indices from i on
def blk_gate(k: Nat, +i: U32, +g: A.Gate, +tbit: U32, +mask: U32, a: Array<F32>) -> Array<F32>:
  match k:
    case 0n:
      a
    case 1n+p:
      blk_gate(p, (i + 1 : U32), g, tbit, mask, pair.at(U32.is_eq((i .&. tbit : U32), 0) && U32.is_eq((i .&. mask : U32), mask), g, a, i, (i .|. tbit : U32)))

# the same gate across two blocks: x from l at i, y from r at i
def put_lr(l: Array<F32>, r: Array<F32>, +i: U32, xy: A.C & A.C) -> Array<F32> & Array<F32>:
  (nx, ny) = xy
  (put2(l, i, nx), put2(r, i, ny))

def bfly_lr.4(rr: Array<F32> & F32, l: Array<F32>, +g: A.Gate, +i: U32, xr: F32, xi: F32, yr: F32) -> Array<F32> & Array<F32>:
  (r, yi) = rr
  put_lr(l, r, i, A.Gate.apply(g, A.C{xr, xi}, A.C{yr, yi}))

def bfly_lr.3(rr: Array<F32> & F32, l: Array<F32>, +g: A.Gate, +i: U32, xr: F32, xi: F32) -> Array<F32> & Array<F32>:
  (r, yr) = rr
  bfly_lr.4(Array.get(F32, r, (2 * i + 1 : U32)), l, g, i, xr, xi, yr)

def bfly_lr.2(rl: Array<F32> & F32, r: Array<F32>, +g: A.Gate, +i: U32, xr: F32) -> Array<F32> & Array<F32>:
  (l, xi) = rl
  bfly_lr.3(Array.get(F32, r, (2 * i : U32)), l, g, i, xr, xi)

def bfly_lr.1(rl: Array<F32> & F32, r: Array<F32>, +g: A.Gate, +i: U32) -> Array<F32> & Array<F32>:
  (l, xr) = rl
  bfly_lr.2(Array.get(F32, l, (2 * i + 1 : U32)), r, g, i, xr)

def bfly_lr(g: A.Gate, l: Array<F32>, r: Array<F32>, +i: U32) -> Array<F32> & Array<F32>:
  bfly_lr.1(Array.get(F32, l, (2 * i : U32)), r, g, i)

def pair_lr.at(go: Bool, g: A.Gate, l: Array<F32>, r: Array<F32>, i: U32) -> Array<F32> & Array<F32>:
  match go:
    case True{}:
      bfly_lr(g, l, r, i)
    case False{}:
      (l, r)

# the gate across the blocks l (the |0> side) and r (the |1> side), at every
# index whose control bits are set; the pair of blocks threads the loop
def blk_mix(k: Nat, +i: U32, +g: A.Gate, +mask: U32, lr: Array<F32> & Array<F32>) -> Array<F32> & Array<F32>:
  match k:
    case 0n:
      lr
    case 1n+p:
      (l, r) = lr
      blk_mix(p, (i + 1 : U32), g, mask, pair_lr.at(U32.is_eq((i .&. mask : U32), mask), g, l, r, i))

# the roles inside a block read as bits of the index: the first role is the
# top bit, and a control adds its bit to the mask
type Sig is Data:
  Sig{targ: Bool, tbit: U32, mask: U32}

def sig.go(rs: List<&2, S.Role>, +bit: U32, targ: Bool, tbit: U32, mask: U32) -> Sig:
  match rs:
    case Nil{}:
      Sig{targ, tbit, mask}
    case S.Targ{} <> t:
      sig.go(t, (bit >> 1n : U32), True{}, bit, mask)
    case S.Ctrl{} <> t:
      sig.go(t, (bit >> 1n : U32), targ, tbit, (mask .|. bit : U32))
    case S.Skip{} <> t:
      sig.go(t, (bit >> 1n : U32), targ, tbit, mask)

def sig(rs: List<&2, S.Role>, lb: Nat) -> Sig:
  sig.go(rs, U32.shln(1, Nat.sub(lb, 1n)), False{}, 0, 0)

def blk_apply.at(s: Sig, g: A.Gate, lb: Nat, a: Array<F32>) -> Array<F32>:
  match s:
    case Sig{False{}, tbit, mask}:
      a
    case Sig{True{}, tbit, mask}:
      blk_gate(Nat.pow(2n, lb), 0, g, tbit, mask, a)

def blk_mix.at(s: Sig, g: A.Gate, lb: Nat, l: Array<F32>, r: Array<F32>) -> Array<F32> & Array<F32>:
  match s:
    case Sig{targ, tbit, mask}:
      blk_mix(Nat.pow(2n, lb), 0, g, mask, (l, r))

# The walk
# --------

def mixf.join(-p: Nat, a: QF(p) & QF(p), b: QF(p) & QF(p)) -> QF(1n+p) & QF(1n+p):
  (l0, r0) = a
  (l1, r1) = b
  ((l0, l1), (r0, r1))

def mixf.ctrl(-p: Nat, l0: QF(p), r0: QF(p), m: QF(p) & QF(p)) -> QF(1n+p) & QF(1n+p):
  (l1, r1) = m
  ((l0, l1), (r0, r1))

# below a target above the blocks: as sim.bend's mix, with the loop over two
# blocks at the leaves
def mixf(m: Nat, +rs: List<&2, S.Role>, +g: A.Gate, +lb: Nat, l: QF(m), r: QF(m)) -> QF(m) & QF(m):
  match m rs:
    case 0n _:
      blk_mix.at(sig(rs, lb), g, lb, l, r)
    case 1n++p Nil{}:
      (l0, l1) = l
      (r0, r1) = r
      a b = mixf(p, Nil{}, g, lb, l0, r0) mixf(p, Nil{}, g, lb, l1, r1)
      mixf.join(p, a, b)
    case 1n++p S.Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mixf.ctrl(p, l0, r0, mixf(p, t, g, lb, l1, r1))
    case 1n++p _ <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mixf(p, t, g, lb, l0, r0) mixf(p, t, g, lb, l1, r1)
      mixf.join(p, a, b)

# above the blocks: as sim.bend's apply; a target inside the blocks is a loop
# over each block
def applyf(m: Nat, +rs: List<&2, S.Role>, +g: A.Gate, +lb: Nat, q: QF(m)) -> QF(m):
  match m rs:
    case 0n _:
      blk_apply.at(sig(rs, lb), g, lb, q)
    case 1n++p Nil{}:
      q
    case 1n++p S.Skip{} <> t:
      (l, r) = q
      a b = applyf(p, t, g, lb, l) applyf(p, t, g, lb, r)
      (a, b)
    case 1n++p S.Ctrl{} <> t:
      (l, r) = q
      (l, applyf(p, t, g, lb, r))
    case 1n++p S.Targ{} <> t:
      (l, r) = q
      mixf(p, t, g, lb, l, r)

# Conversion
# ----------

def leaf(ra: Array<F32> & F32, rb: Array<F32> & F32) -> A.C:
  (a, re) = ra
  (b, im) = rb
  A.C{re, im}

# the tree of the 2^k amplitudes from index i of a block, read from two copies
# so that both halves can be built in parallel
def blk_tree(k: Nat, +i: U32, ab: Array<F32> & Array<F32>) -> S.Q(k):
  match k:
    case 0n:
      (a, b) = ab
      leaf(Array.get(F32, a, (2 * i : U32)), Array.get(F32, b, (2 * i + 1 : U32)))
    case 1n++p:
      (a, b) = ab
      l r = blk_tree(p, i, Array.clone(F32, a)) blk_tree(p, (i + U32.shln(1, p) : U32), Array.clone(F32, b))
      (l, r)

def to_tree(m: Nat, +lb: Nat, q: QF(m)) -> S.Q(Nat.add(m, lb)):
  match m:
    case 0n:
      blk_tree(lb, 0, Array.clone(F32, q))
    case 1n++p:
      (l, r) = q
      a b = to_tree(p, lb, l) to_tree(p, lb, r)
      (a, b)

def set_leaf(+i: U32, c: A.C, a: Array<F32>) -> Array<F32>:
  match c:
    case A.C{re, im}:
      Array.set(F32, Array.set(F32, a, (2 * i : U32), re), (2 * i + 1 : U32), im)

# the 2^k amplitudes of a tree written from index i of a block
def fill(k: Nat, +i: U32, q: S.Q(k), a: Array<F32>) -> Array<F32>:
  match k:
    case 0n:
      set_leaf(i, q, a)
    case 1n++p:
      (l, r) = q
      fill(p, (i + U32.shln(1, p) : U32), r, fill(p, i, l, a))

def of_tree(m: Nat, +lb: Nat, q: S.Q(Nat.add(m, lb))) -> QF(m):
  match m:
    case 0n:
      fill(lb, 0, q, zeros_blk(lb))
    case 1n++p:
      (l, r) = q
      a b = of_tree(p, lb, l) of_tree(p, lb, r)
      (a, b)

# Circuits and readout
# --------------------

# a circuit on n = m + lb qubits; a two-qubit gate goes through the tree
def runf(+m: Nat, +lb: Nat, ops: List<&2, S.Op>, q: QF(m)) -> QF(m):
  match ops:
    case Nil{}:
      q
    case S.Op{t, cs, g} <> rest:
      runf(m, lb, rest, applyf(m, S.roles(Nat.add(m, lb), t, cs), g, lb, q))
    case S.Op4{t1, t2, cs, g} <> rest:
      runf(m, lb, rest, of_tree(m, lb, S.apply4(Nat.add(m, lb), S.roles4(Nat.add(m, lb), t1, t2, cs), g, to_tree(m, lb, q))))

# the sum of the squares of a block's floats from index i on, k more to read
def blk_norm(k: Nat, +i: U32, acc: F32, r: Array<F32> & F32) -> F32:
  match k:
    case 0n:
      (a, +v) = r
      F32.add(acc, F32.mul(v, v))
    case 1n+p:
      (a, +v) = r
      blk_norm(p, (i + 1 : U32), F32.add(acc, F32.mul(v, v)), Array.get(F32, a, (i + 1 : U32)))

def norm2f(m: Nat, +lb: Nat, q: QF(m)) -> F32:
  match m:
    case 0n:
      blk_norm(Nat.sub(Nat.pow(2n, 1n+lb), 1n), 0, 0.0, Array.get(F32, q, 0))
    case 1n++p:
      (l, r) = q
      a b = norm2f(p, lb, l) norm2f(p, lb, r)
      F32.add(a, b)

def showf(+m: Nat, +lb: Nat, q: QF(m)) -> String:
  S.show(Nat.add(m, lb), to_tree(m, lb, q))
