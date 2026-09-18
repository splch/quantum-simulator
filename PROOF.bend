# The proofs. A match is the case analysis, the self-call is the induction
# hypothesis, and %e : P rewrites the goal with the equation e: it folds e's
# right side into its left wherever P marks it with _. Every helper lemma is
# therefore stated with the term its callers eliminate on the right.
import Base
import ./sim.bend as S
import ./circuits.bend as G
import ./rotations.bend as R
import ./LAWS.bend as Laws

# Nat and list lemmas
# -------------------

def add_zero(a: Nat) -> {a == Nat.add(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+p == 1n+_ : Nat}
      {==}

def add_succ(a: Nat, -b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

def len_append(-A: Data, xs: List<&2, A>, ys: List<&2, A>) -> {Nat.add(List.length(&2, A, xs), List.length(&2, A, ys)) == List.length(&2, A, List.append(&2, A, xs, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %len_append(A, t, ys) : {1n+Nat.add(List.length(&2, A, t), List.length(&2, A, ys)) == 1n+_ : Nat}
      {==}

# Gates
# -----

def Laws.nil_id(n, g, q):
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

# induction on n; the step destructures q and rewrites each half with the
# hypothesis
def Laws.skip_id(n, g, q):
  match n:
    case 0n:
      {==}
    case 1n++p:
      (l, r) = q
      %Laws.skip_id(p, g, l) : {(S.apply(p, Laws.skips(p), g, l), S.apply(p, Laws.skips(p), g, r)) == (_, r) : S.Q(1n+p)}
      %Laws.skip_id(p, g, r) : {(S.apply(p, Laws.skips(p), g, l), S.apply(p, Laws.skips(p), g, r)) == (S.apply(p, Laws.skips(p), g, l), _) : S.Q(1n+p)}
      {==}

def Laws.ctrl_keeps_zero(p, rs, g, l, r):
  {==}

# induction on the first circuit; the cons case is the hypothesis at the
# state after its first gate
def Laws.run_append(n, xs, ys, q):
  match xs:
    case Nil{}:
      {==}
    case S.Op{t, cs, g} <> rest:
      Laws.run_append(n, rest, ys, S.apply(n, S.roles(n, t, cs), g, q))
    case S.Op4{t1, t2, cs, g} <> rest:
      Laws.run_append(n, rest, ys, S.apply4(n, S.roles4(n, t1, t2, cs), g, q))

# Roles
# -----

def Laws.ctrls_len(n, cs):
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Laws.ctrls_len(p, S.down(cs)) : {1n+p == 1n+_ : Nat}
      {==}

def Laws.roles_len(n, t, cs):
  match n t:
    case 0n _:
      {==}
    case 1n+p 0n:
      %Laws.ctrls_len(p, S.down(cs)) : {1n+p == 1n+_ : Nat}
      {==}
    case 1n+p 1n+u:
      %Laws.roles_len(p, u, S.down(cs)) : {1n+p == 1n+_ : Nat}
      {==}

def Laws.roles4_len(n, t1, t2, cs):
  match n t1:
    case 0n _:
      {==}
    case 1n+p 0n:
      %Laws.roles_len(p, Nat.sub(t2, 1n), S.down(cs)) : {1n+p == 1n+_ : Nat}
      {==}
    case 1n+p 1n+u:
      %Laws.roles4_len(p, u, Nat.sub(t2, 1n), S.down(cs)) : {1n+p == 1n+_ : Nat}
      {==}

# induction on the target's index, shifting the controls down each level
def Laws.roles_targ(t, m, cs):
  match t:
    case 0n:
      {==}
    case 1n+u:
      Laws.roles_targ(u, m, S.down(cs))

# below the target, the one control at index d reads Ctrl
def ctrls_ctrl(d: Nat, m: Nat) -> {List.get(&2, S.Role, S.ctrls(Nat.add(d, 1n+m), [d]), d) == Some{S.Ctrl{}} : Maybe<&2, S.Role>}:
  match d:
    case 0n:
      {==}
    case 1n+e:
      ctrls_ctrl(e, m)

def Laws.roles_ctrl_above(c, d, m):
  match c:
    case 0n:
      {==}
    case 1n+u:
      Laws.roles_ctrl_above(u, d, m)

def Laws.roles_ctrl_below(t, d, m):
  match t:
    case 0n:
      ctrls_ctrl(d, m)
    case 1n+u:
      Laws.roles_ctrl_below(u, d, m)

# below the target with no controls, index d reads Skip
def ctrls_skip(d: Nat, m: Nat) -> {List.get(&2, S.Role, S.ctrls(Nat.add(d, 1n+m), Nil{}), d) == Some{S.Skip{}} : Maybe<&2, S.Role>}:
  match d:
    case 0n:
      {==}
    case 1n+e:
      ctrls_skip(e, m)

def Laws.roles_skip_above(i, d, m):
  match i:
    case 0n:
      {==}
    case 1n+u:
      Laws.roles_skip_above(u, d, m)

def Laws.roles_skip_below(t, d, m):
  match t:
    case 0n:
      ctrls_skip(d, m)
    case 1n+u:
      Laws.roles_skip_below(u, d, m)

# Measurement
# -----------

# at the target depth the outcome decides the shape, so both outcomes are
# cases; above it the hypothesis applies to each half
def Laws.project_idem(n, k, b, q):
  match n k b:
    case 0n _ _:
      {==}
    case 1n++p 0n False{}:
      (l, r) = q
      {==}
    case 1n++p 0n True{}:
      (l, r) = q
      {==}
    case 1n++p 1n++j _:
      (l, r) = q
      %Laws.project_idem(p, j, b, l) : {(S.project(p, j, b, S.project(p, j, b, l)), S.project(p, j, b, S.project(p, j, b, r))) == (_, S.project(p, j, b, r)) : S.Q(1n+p)}
      %Laws.project_idem(p, j, b, r) : {(S.project(p, j, b, S.project(p, j, b, l)), S.project(p, j, b, S.project(p, j, b, r))) == (S.project(p, j, b, S.project(p, j, b, l)), _) : S.Q(1n+p)}
      {==}

def Laws.project_zeros(n, k, b):
  match n k b:
    case 0n _ _:
      {==}
    case 1n++p 0n False{}:
      {==}
    case 1n++p 0n True{}:
      {==}
    case 1n++p 1n++j _:
      %Laws.project_zeros(p, j, b) : {(S.project(p, j, b, S.zeros(p)), S.project(p, j, b, S.zeros(p))) == (_, _) : S.Q(1n+p)}
      {==}

def Laws.project_other_zero(p, l, r):
  ({==}, {==})

# Circuits
# --------

def Laws.rots_len(d, tg, c, angle):
  match d:
    case 0n:
      {==}
    case 1n+e:
      %Laws.rots_len(e, tg, 1n+c, F32.mul(angle, 0.5)) : {1n+e == 1n+_ : Nat}
      {==}

# qft.go(1+r, off) is one H, r rotations and qft.go(r, off + 1)
def Laws.qft_go_len(m, off):
  match m:
    case 0n:
      {==}
    case 1n++r:
      %len_append(S.Op, R.qft.rots(r, off, 1n+off, F32.mul(F32.pi(), 0.5)), R.qft.go(r, 1n+off)) : {Laws.tri(1n+r) == 1n+_ : Nat}
      %Laws.rots_len(r, off, 1n+off, F32.mul(F32.pi(), 0.5)) : {Laws.tri(1n+r) == 1n+Nat.add(_, List.length(&2, S.Op, R.qft.go(r, 1n+off))) : Nat}
      %Laws.qft_go_len(r, 1n+off) : {Laws.tri(1n+r) == 1n+Nat.add(r, _) : Nat}
      {==}

def Laws.swaps_len(k, lo, hi):
  match k:
    case 0n:
      {==}
    case 1n+j:
      %Laws.swaps_len(j, 1n+lo, Nat.sub(hi, 1n)) : {Nat.mul(1n+j, 3n) == 3n+_ : Nat}
      {==}

def Laws.qft_len(n):
  %len_append(S.Op, R.qft.go(n, 0n), R.qft.swaps(Nat.div(n, 2n), 0n, Nat.sub(n, 1n))) : {Nat.add(Laws.tri(n), Nat.mul(Nat.div(n, 2n), 3n)) == _ : Nat}
  %Laws.qft_go_len(n, 0n) : {Nat.add(Laws.tri(n), Nat.mul(Nat.div(n, 2n), 3n)) == Nat.add(_, List.length(&2, S.Op, R.qft.swaps(Nat.div(n, 2n), 0n, Nat.sub(n, 1n)))) : Nat}
  %Laws.swaps_len(Nat.div(n, 2n), 0n, Nat.sub(n, 1n)) : {Nat.add(Laws.tri(n), Nat.mul(Nat.div(n, 2n), 3n)) == Nat.add(Laws.tri(n), _) : Nat}
  {==}

# Sampling
# --------

# tally counts up from its accumulator
def tally_acc(us: List<&2, F32>, acc: Nat) -> {1n+S.tally(us, acc) == S.tally(us, 1n+acc) : Nat}:
  match us:
    case Nil{}:
      {==}
    case u <> rest:
      tally_acc(rest, 1n+acc)

# one uniform lands on exactly one side, whichever way its comparison went
def put_count(b: Bool, c: F32, u: F32, +a0: List<&2, F32>, +a1: List<&2, F32>) -> {1n+Nat.add(S.tally(a0, 0n), S.tally(a1, 0n)) == Nat.add(S.tally(S.lows.put(c, u, b, a0), 0n), S.tally(S.highs.put(c, u, b, a1), 0n)) : Nat}:
  match b:
    case False{}:
      %tally_acc(a1, 0n) : {1n+Nat.add(S.tally(a0, 0n), S.tally(a1, 0n)) == Nat.add(S.tally(a0, 0n), _) : Nat}
      add_succ(S.tally(a0, 0n), S.tally(a1, 0n))
    case True{}:
      %tally_acc(a0, 0n) : {1n+Nat.add(S.tally(a0, 0n), S.tally(a1, 0n)) == Nat.add(_, S.tally(a1, 0n)) : Nat}
      {==}

# routing a list splits its tally between the two sides, on top of whatever
# the two accumulators already hold
def split_go(+c: F32, +us: List<&2, F32>, +a0: List<&2, F32>, +a1: List<&2, F32>) -> {Nat.add(S.tally(us, 0n), Nat.add(S.tally(a0, 0n), S.tally(a1, 0n))) == Nat.add(S.tally(S.lows.go(c, us, a0), 0n), S.tally(S.highs.go(c, us, a1), 0n)) : Nat}:
  match us:
    case Nil{}:
      {==}
    case u <> rest:
      %split_go(c, rest, S.lows.put(c, u, F32.is_lt(u, c), a0), S.highs.put(c, u, F32.is_lt(u, c), a1)) : {Nat.add(S.tally(u <> rest, 0n), Nat.add(S.tally(a0, 0n), S.tally(a1, 0n))) == _ : Nat}
      %tally_acc(rest, 0n) : {Nat.add(_, Nat.add(S.tally(a0, 0n), S.tally(a1, 0n))) == Nat.add(S.tally(rest, 0n), Nat.add(S.tally(S.lows.put(c, u, F32.is_lt(u, c), a0), 0n), S.tally(S.highs.put(c, u, F32.is_lt(u, c), a1), 0n))) : Nat}
      %put_count(F32.is_lt(u, c), c, u, a0, a1) : {Nat.add(1n+S.tally(rest, 0n), Nat.add(S.tally(a0, 0n), S.tally(a1, 0n))) == Nat.add(S.tally(rest, 0n), _) : Nat}
      add_succ(S.tally(rest, 0n), Nat.add(S.tally(a0, 0n), S.tally(a1, 0n)))

def split_total(+c: F32, +us: List<&2, F32>) -> {S.tally(us, 0n) == Nat.add(S.tally(S.lows(c, us), 0n), S.tally(S.highs(c, us), 0n)) : Nat}:
  %split_go(c, us, Nil{}, Nil{}) : {S.tally(us, 0n) == _ : Nat}
  add_zero(S.tally(us, 0n))

def counts_append(+xs: List<&2, S.Bin>, +ys: List<&2, S.Bin>) -> {Nat.add(Laws.counts(xs), Laws.counts(ys)) == Laws.counts(List.append(&2, S.Bin, xs, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case S.Bin{bs, k} <> t:
      %counts_append(t, ys) : {Nat.add(Nat.add(k, Laws.counts(t)), Laws.counts(ys)) == Nat.add(k, _) : Nat}
      add_assoc(k, Laws.counts(t), Laws.counts(ys))

# induction on the depth: a node's histogram is its halves' histograms
# appended, and its uniforms split between the halves
def Laws.shots_total(n, bits, us, w):
  match n us:
    case 0n Nil{}:
      {==}
    case 1n+p Nil{}:
      {==}
    case 0n u <> rest:
      add_zero(S.tally(u <> rest, 0n))
    case 1n++p u <> rest:
      (+c, lr) = w
      (+l, +r) = lr
      %counts_append(S.shots(p, bits ++ "0", S.lows(c, u <> rest), l), S.shots(p, bits ++ "1", S.highs(c, u <> rest), r)) : {S.tally(u <> rest, 0n) == _ : Nat}
      %Laws.shots_total(p, bits ++ "0", S.lows(c, u <> rest), l) : {S.tally(u <> rest, 0n) == Nat.add(_, Laws.counts(S.shots(p, bits ++ "1", S.highs(c, u <> rest), r))) : Nat}
      %Laws.shots_total(p, bits ++ "1", S.highs(c, u <> rest), r) : {S.tally(u <> rest, 0n) == Nat.add(S.tally(S.lows(c, u <> rest), 0n), _) : Nat}
      split_total(c, u <> rest)

#|All terms check.
