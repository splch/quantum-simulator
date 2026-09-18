# Bend 2.0.5 findings for the quantum simulator (smoke tests run 2026-09-17)

Machine: Apple M5 Pro, 18 cores, macOS 25.6.0, Apple clang 21.0.0, Bun 1.4.2. `bend` was not installed; every run used `BEND_NO_TELEMETRY=1 bun $SP/bend/bend2/main.ts <file>` on a shallow clone of `bendlang/bend` (`bend --version` prints `bend 2.0.5`). Files are in `$SP/smoke/`; the API survey is `$SP/bend-api.md`.

Evidence markers: [V] verified by running here, [R] read in the repo.

## Smoke tests

| file | checks | runs | output or verbatim error |
|---|---|---|---|
| `fshow.bend` | yes | JS | `0.70710677 \| 1 \| -0 \| -0.70710677 \| 0 \| 1.4142135 \| 0.70710677` |
| `q.bend` (final, below) | yes | JS | `0.70710677+0i 0+0i 0+0i 0.70710677+0i` (H on qubit 0, CNOT 0 -> 1, from ket0(2n): the Bell state) |
| `q.bend` first draft, `(p0, q0) = a` after a parallel let | no | | `a parameter or field scrutinee (a match cannot scrutinize a local binder: give it its own def)` |
| `q.bend` second draft, `case 1n+p:` with `p` used twice | no | | `expected : p / observed : p (consumed more than once)` at `(zeros(p), zeros(p))` |
| `qdata.bend` with `def Q(n: Nat) -> Data` and branch `Q(p) & Q(p)` | no | | `expected : Data / observed : Type` at `Q(p) & Q(p)` |
| `qdata.bend` with branch `Sigma<&2, &2, Q(p), _ => Q(p)>` and `def dup(n: Nat, +q: Q(n)) -> Q(n) & Q(n): (q, q)` | yes | JS | `ok` |
| `qdata.bend` with `(a, b) = dup(1n, zeros(1n))` in main | no | | `a parameter or field scrutinee (a match cannot scrutinize a computed value: give it its own def)` |
| `par.bend` spelling A: `a b = two(x) two(..)` then `spellA.join(a, b)` whose params are destructured | yes | JS | `26` |
| `par2.bend`: `(p0, q0) (p1, q1) = two(x) two(..)` | no | | `expected : a pattern (a binder or a constructor) / observed : (p0, q0)(p1, q1)` |
| `par3.bend`: `Tuple{p0, q0} Tuple{p1, q1} = two(x) two(..)` | no | | `a name (a parallel let binds names; destructure in its body)` |
| `plus.bend`: `+x = l` with `l : Q(n)` in the `0n` branch | no | | `expected : Data / observed : Type` with context `l : C` |
| `plus2.bend`: `+x = {l : C}` | yes | JS | `ok` |
| `laws.bend`: `nil_id` and `skip_id` over `import ./q.bend as S` | yes | | `All terms check.` |
| `laws.bend` first draft, motive `{(_, apply(..r)) == (l, r)}` | no | | `expected : {(q.apply(p^0, ..., l), q.apply(p^0, ..., r)) == (l, r) : Sigma<&1, &1, q.Q(p^0), _ => q.Q(p^0)>} / observed : {(l, q.apply(p^0, ..., r)) == (l, r) : ...}` |
| `q10.bend` (`run(10n)`, JS) | yes | JS 0.08 s | `0.99999976 0.031249996+0i` (norm, first amplitude; exact would be `1 0.03125`) |
| `q20.bend` with `run!(20n) -> String` | yes | CPU yes, GPU no | GPU: `bend: a function the device does not hold` after 4.5 s (n=20) and 70 s (n=24); CPU lanes fine |
| `q20g.bend` / `q24g.bend` (`run! -> F32 & F32`, show on the host) | yes | all lanes | see timings |
| `run.fin(-n: Nat, ...)` using `n` live | no | | `expected : -n / observed : n (consumed more than once)` |

Build times [V]: `-o` with a `!` mark 1.3 to 1.5 s wall (writes `<name>.gpu`, 298 KB, at build time); without `!` 0.38 s. Binaries are about 208 KB.

## Timings, H on every qubit of |0..0> then a full clone and a norm fold [V]

`run(n)` = `norm(n, a)` and `|<0..0|b>|^2` of `twice(n, hall(n, n, ket0(n)))`: n gate passes over a 2^n-leaf tree, one clone, one fold. `--gpu off` lanes and the unmarked binary agree byte for byte; the GPU lane prints the same bytes.

| n | leaves | 1 thread | 18 threads | GPU (Metal, `!`) | max RSS (CPU) | output |
|---|---|---|---|---|---|---|
| 16 | 65,536 | 0.03 s | 0.03 s | 0.39 s | 12 MB | `0.99999976 0.000015258785` |
| 20 | 1,048,576 | 0.13 s | 0.06 s | 4.81 s (4.82 s warm) | 75 MB | `0.99999976 9.536741e-7` |
| 24 | 16,777,216 | 2.06 s (1.97 user) | 0.55 s (2.61 user, 0.96 sys) | 76.8 s | 1.08 GB | `0.99999976 5.960463e-8` |

- 2^-16, 2^-20, 2^-24 are the exact probabilities; the norm drift (1 - 2.4e-7) is the F32 rounding of 0.70710677, identical on every lane.
- Single thread: 24 passes over 16.8M leaves in 1.97 s is about 4.9 ns per leaf per pass, including the clone and the fold. Speedup on 18 threads is 3.7x; `sys` time of 0.96 s suggests page faults on the fresh heap dominate.
- The GPU lane is 37x slower than one CPU thread at n=24 and 140x slower than 18 threads. This tree walk is the "divergent work" the GUIDE says stays on the CPU. Recommendation: do not use `!` for the state tree; leave it for a future flat-array kernel if one is written.
- Unmarked binaries parallelize on the CPU: `q24nomark --threads 1` 2.15 s vs default 0.55 s. This settles bend-notes.md's open question about issue #767: plain parallel lets fork on the CPU without `!`.
- The GPU error `bend: a function the device does not hold` appears when the `!` closure contains `F32.show`/`++` (String building); it surfaces only after the device part has run (4.5 s / 70 s), so it is a late fail-stop, not a compile error.

## Final working `q.bend` (JS: prints the Bell state)

```python
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
```

## `laws.bend` (checks: "All terms check.")

```python
import Base
import ./q.bend as S

def skips(n: Nat) -> List<&2, S.Role>:
  match n:
    case 0n:
      Nil{}
    case 1n++p:
      S.Skip{} <> skips(p)

# LAW 1: an empty role list changes nothing (trivial: apply returns q at once)
law nil_id:
  for n: Nat
  for q: S.Q(n)
  {S.apply(n, Nil{}, S.H(), q) == q : S.Q(n)}

def nil_id(n, q):
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

# LAW 2: a gate that targets no qubit (all Skip) changes nothing; by
# induction on n, destructuring q in the step case
law skip_id:
  for n: Nat
  for q: S.Q(n)
  {S.apply(n, skips(n), S.H(), q) == q : S.Q(n)}

def skip_id(n, q):
  match n:
    case 0n:
      {==}
    case 1n++p:
      (l, r) = q
      %skip_id(p, l) : {(S.apply(p, skips(p), S.H(), l), S.apply(p, skips(p), S.H(), r)) == (_, r) : S.Q(1n+p)}
      %skip_id(p, r) : {(S.apply(p, skips(p), S.H(), l), S.apply(p, skips(p), S.H(), r)) == (S.apply(p, skips(p), S.H(), l), _) : S.Q(1n+p)}
      {==}
```

## `q20g.bend` additions used for the timings

```python
def skips(n: Nat) -> List<&2, S.Role>:
  match n:
    case 0n:
      Nil{}
    case 1n++p:
      S.Skip{} <> skips(p)

# roles for a one-qubit gate on qubit k of n (k counted from the root)
def roles(n: Nat, k: Nat) -> List<&2, S.Role>:
  match n k:
    case 0n _:
      Nil{}
    case 1n++p 0n:
      S.Targ{} <> skips(p)
    case 1n++p 1n++j:
      S.Skip{} <> roles(p, j)

# H on qubits k-1 .. 0
def hall(k: Nat, +n: Nat, q: S.Q(n)) -> S.Q(n):
  match k:
    case 0n:
      q
    case 1n++j:
      hall(j, n, S.apply(n, roles(n, j), S.H(), q))

def norm(n: Nat, q: S.Q(n)) -> F32:
  match n:
    case 0n:
      S.C.norm2(q)
    case 1n++p:
      (l, r) = q
      a b = norm(p, l) norm(p, r)
      F32.add(a, b)

# the leftmost amplitude, <0..0|q>
def first(n: Nat, q: S.Q(n)) -> S.C:
  match n:
    case 0n:
      q
    case 1n+p:
      (l, r) = q
      first(p, l)

# (norm, first amplitude) of H^n |0..0>: expect (1, 2^(-n/2)); numeric only,
# so that run! is device-representable (String building is host-only)
def run.fin(+n: Nat, q: S.Q(n) & S.Q(n)) -> F32 & F32:
  (a, b) = q
  (norm(n, a), S.C.norm2(first(n, b)))

def run(+n: Nat) -> F32 & F32:
  run.fin(n, S.twice(n, hall(n, n, S.ket0(n))))

def fin(r: F32 & F32) -> IO(Unit):
  (nrm, p0) = r
  IO.print(F32.show(nrm) ++ " " ++ F32.show(p0))

def main() -> IO(Unit):
  fin(run!(20n))
```

## Answers to the design questions

1. `match n` refines `q: Q(n)`: `(l, r) = q` checks in the `1n++p` branch and `q` is accepted as `C` in the `0n` branch (`C.show(q)`, `mix.leaf(g, l, r)` with `+x: C` params). [V]
2. Returning `mix(p, t, g, l, r) : Q(p) & Q(p)` where `Q(1n+p)` is expected checks; `mix.join(-p, a: Q(p) & Q(p), b: Q(p) & Q(p)) -> Q(1n+p) & Q(1n+p)` checks. [V]
3. `+x = l` for `l : Q(0n)` does NOT check (`expected : Data / observed : Type`, context shows `l : C`); `+x = {l : C}` does, and so does passing `l` to a `+x: C` parameter. [V]
4. `def Q(n: Nat) -> Data` works only if the pair branch is `Sigma<&2, &2, Q(p), _ => Q(p)>`; `A & B` is `Kind(&1)` always. Then `+q: Q(n)` can be used twice (a whole-state clone by refcount). Tradeoff: a `Data` tree carries reference counts and loses the "one owner, free on match" in-place update that made the `Type` tree fast; not measured. [V for checking, not for speed]
5. Destructuring lets are matches and may only scrutinize a parameter or a pattern-bound field. The results of a parallel let or of a call must be passed to a helper def that destructures its parameters (Base does this everywhere: `Array.swap.lo`, `Nat.div.fin`). The parallel let binds plain names, optionally `+a +b`; no patterns on its left side. [V]
6. A `Nat` predecessor used twice needs `case 1n++p:`; a `Nat`/`U32`/`F32` parameter used twice needs `+`; erased `-x` may not be used live. [V]
7. Modules: `import ./q.bend as S`; `S.Q(n)` is usable as a type in another file's laws and defs; dotted names nest (`S.C.norm2`). [V]
8. Proofs over the family work: `skip_id` by induction on `n`, destructuring `for q: S.Q(n)` in the step case, two rewrites with the IH, `{==}`. The motive's `_` marks the right-hand side of the equation used. [V]

## Idioms worth copying

- Tree recursion: `match n` first (shrinking parameter first), parallel let over both halves, join through a helper def. No depth cutoff in any bench or demo; leaves are the base case. [R]
- `!` once on the top-level call in `main`; everything reachable must be device-representable (numbers, constructors); build Strings on the host. [R][V]
- Constants: `def rh() -> F32: 0.70710677` or nbody's `fl(n, d)`; `F32.pi()` exists; `F32.sqrt`, `sin`, `cos`, `exp`, `atan2`, `pow`, `abs`, `neg`, `hypot`, `square` exist. [R][V]
- PRNG: nbody's xorshift32 over `+U32` with `U32.shln/shrn` by `Nat`. No random effect in Base; seed from `IO.now() -> IO(Nat)`. [R]
- Tests: `#|` lines pin stdout and `#|exit N`; `law main: IO(Unit)` then `def main():`. [R]

## Contradictions or corrections to bend-notes.md

- "Relevance" section: a complex amplitude does not need hand-rolled U32/F32 arrays; `type C is Data: C{re: F32, im: F32}` plus a `Nat`-indexed tree family works, checks, and runs at about 4.9 ns per amplitude per gate pass single-threaded (n=24), which is within a small factor of a C state-vector loop. The tree, not `Array`, is the natural representation here. [V]
- Open question "whether plain (non-`!`) calls parallelize on the CPU": yes (2.15 s -> 0.55 s with no `!`). [V]
- "The GPU gives 50x to 75x on uniform work": for this tree workload the GPU lane is 37x slower than one CPU thread. [V]
- The nbody bench comment "no float literal syntax in Bend4" is stale; `0.0`, `1.0`, `0.70710677`, `1.5` parse as F32. [V]
- Notes say `Map` exposes `new set get has del keys`; Base also has `Map.put`, `Map.pop`, `Map.union`, `Map.size`, `Map.values`, `Map.to_list`, `Map.from_list`, and `Set` (`new add has del size to_list from_list`). [R]
- Notes say F32 has `is_lt` family and `show`; the full list is in bend-api.md (30 primitives plus min max clamp lerp square hypot round pi from_nat to_nat). `F32.show` takes `+a`. [R]
- `U32.shl`/`U32.shr` shift by one; `U32.shln(a, n: Nat)`/`U32.shrn` shift by a `Nat`. The `<< >>` sugar shifts by a `Nat`. [R]
- Error messages print module-qualified names by file stem (`q.apply`) and shadowed binders as `p^0`. [V]

## Not done / caveats

- `1n+p` vs `1n++p` inside `def Q(n) -> Type` (dead code) was not isolated; `1n++p` was used everywhere after the `zeros` error.
- The `Data`-kinded tree (`qdata.bend`) was only type-checked, not timed.
- A negative float literal (`-0.7`) was not tried.
- No CUDA hardware; Metal only. The GPU lane's 4.8 s at n=20 includes no compile (second run identical).
- The shell mishaps in this session (zsh not splitting `$BEND` and `$lane`) produced two spurious "failures" that were retracted after rerunning; no Bend failure is recorded from them.
