# The laws: claims about the simulator's structure that hold for every input.
# They are float-free, since every F32 primitive is an opaque law. PROOF.bend
# proves each one, and `bend PROOF.bend` prints "All terms check." only when
# every law here has a proof.
import Base
import ./amp.bend as A
import ./sim.bend as S
import ./circuits.bend as G
import ./rotations.bend as R

# n Skips
def skips(n: Nat) -> List<&2, S.Role>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      S.Skip{} <> skips(p)

# the triangular number 1 + 2 + .. + n
def tri(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n++p:
      Nat.add(1n+p, tri(p))

# Gates
# -----

# LAW: an empty role list changes nothing
law nil_id:
  for n: Nat
  for g: A.Gate
  for q: S.Q(n)
  {S.apply(n, Nil{}, g, q) == q : S.Q(n)}

# LAW: a gate that targets no qubit changes nothing
law skip_id:
  for n: Nat
  for +g: A.Gate
  for q: S.Q(n)
  {S.apply(n, skips(n), g, q) == q : S.Q(n)}

# LAW: a control above the target leaves the |0> subtree untouched and acts
# on the |1> subtree alone
law ctrl_keeps_zero:
  for p: Nat
  for rs: List<&2, S.Role>
  for g: A.Gate
  for l: S.Q(p)
  for r: S.Q(p)
  {S.apply(1n+p, S.Ctrl{} <> rs, g, (l, r)) == (l, S.apply(p, rs, g, r)) : S.Q(1n+p)}

# LAW: running two circuits in sequence is running their concatenation
law run_append:
  for +n: Nat
  for xs: List<&2, S.Op>
  for ys: List<&2, S.Op>
  for q: S.Q(n)
  {S.run(n, List.append(&2, S.Op, xs, ys), q) == S.run(n, ys, S.run(n, xs, q)) : S.Q(n)}

# Roles
# -----

# LAW: the role list of a gate on n qubits has one entry per qubit
law roles_len:
  for n: Nat
  for t: Nat
  for cs: List<&2, Nat>
  {n == List.length(&2, S.Role, S.roles(n, t, cs)) : Nat}

law ctrls_len:
  for n: Nat
  for cs: List<&2, Nat>
  {n == List.length(&2, S.Role, S.ctrls(n, cs)) : Nat}

law roles4_len:
  for n: Nat
  for t1: Nat
  for t2: Nat
  for cs: List<&2, Nat>
  {n == List.length(&2, S.Role, S.roles4(n, t1, t2, cs)) : Nat}

# LAW: the target reads Targ; n is written as t + 1 + m so that t is in range
law roles_targ:
  for t: Nat
  for m: Nat
  for cs: List<&2, Nat>
  {List.get(&2, S.Role, S.roles(Nat.add(t, 1n+m), t, cs), t) == Some{S.Targ{}} : Maybe<&2, S.Role>}

# LAW: a control reads Ctrl, whether it sits above the target (c, then
# t = c + 1 + d) or below it (t, then c = t + 1 + d); n = c + d + 2 + m
# keeps both in range
law roles_ctrl_above:
  for c: Nat
  for d: Nat
  for m: Nat
  {List.get(&2, S.Role, S.roles(Nat.add(c, 1n+Nat.add(d, 1n+m)), Nat.add(c, 1n+d), [c]), c) == Some{S.Ctrl{}} : Maybe<&2, S.Role>}

law roles_ctrl_below:
  for t: Nat
  for d: Nat
  for m: Nat
  {List.get(&2, S.Role, S.roles(Nat.add(t, 1n+Nat.add(d, 1n+m)), t, [Nat.add(t, 1n+d)]), Nat.add(t, 1n+d)) == Some{S.Ctrl{}} : Maybe<&2, S.Role>}

# LAW: with no controls, every other qubit reads Skip, above the target
# (i, then t = i + 1 + d) and below it (t, then i = t + 1 + d)
law roles_skip_above:
  for i: Nat
  for d: Nat
  for m: Nat
  {List.get(&2, S.Role, S.roles(Nat.add(i, 1n+Nat.add(d, 1n+m)), Nat.add(i, 1n+d), Nil{}), i) == Some{S.Skip{}} : Maybe<&2, S.Role>}

law roles_skip_below:
  for t: Nat
  for d: Nat
  for m: Nat
  {List.get(&2, S.Role, S.roles(Nat.add(t, 1n+Nat.add(d, 1n+m)), t, Nil{}), Nat.add(t, 1n+d)) == Some{S.Skip{}} : Maybe<&2, S.Role>}

# Measurement
# -----------

# LAW: projecting twice onto the same outcome is projecting once
law project_idem:
  for n: Nat
  for k: Nat
  for +b: Bool
  for q: S.Q(n)
  {S.project(n, k, b, S.project(n, k, b, q)) == S.project(n, k, b, q) : S.Q(n)}

# LAW: projecting the zero state leaves it zero
law project_zeros:
  for n: Nat
  for k: Nat
  for +b: Bool
  {S.project(n, k, b, S.zeros(n)) == S.zeros(n) : S.Q(n)}

# LAW: after projecting qubit 0 onto an outcome, the branch for the other
# outcome is zeros
law project_other_zero:
  for p: Nat
  for l: S.Q(p)
  for r: S.Q(p)
  {S.project(1n+p, 0n, False{}, (l, r)) == (l, S.zeros(p)) : S.Q(1n+p)} & {S.project(1n+p, 0n, True{}, (l, r)) == (S.zeros(p), r) : S.Q(1n+p)}

# Circuits
# --------

# LAW: the QFT on n qubits has n(n+1)/2 gates before its swaps and
# 3 floor(n/2) more for them
law rots_len:
  for d: Nat
  for tg: Nat
  for c: Nat
  for angle: F32
  {d == List.length(&2, S.Op, R.qft.rots(d, tg, c, angle)) : Nat}

law qft_go_len:
  for m: Nat
  for +off: Nat
  {tri(m) == List.length(&2, S.Op, R.qft.go(m, off)) : Nat}

law swaps_len:
  for k: Nat
  for lo: Nat
  for hi: Nat
  {Nat.mul(k, 3n) == List.length(&2, S.Op, R.qft.swaps(k, lo, hi)) : Nat}

law qft_len:
  for +n: Nat
  {Nat.add(tri(n), Nat.mul(Nat.div(n, 2n), 3n)) == List.length(&2, S.Op, R.qft(n)) : Nat}

# Sampling
# --------

# the shots in a histogram
def counts(bins: List<&2, S.Bin>) -> Nat:
  match bins:
    case Nil{}:
      0n
    case S.Bin{bits, k} <> rest:
      Nat.add(k, counts(rest))

# LAW: the histogram's counts add up to the number of uniforms, whichever way
# each F32 comparison in the routing goes
law shots_total:
  for n: Nat
  for +bits: String
  for +us: List<&2, F32>
  for +w: S.W(n)
  {S.tally(us, 0n) == counts(S.shots(n, bits, us, w)) : Nat}
