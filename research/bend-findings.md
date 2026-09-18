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

## Findings from phases 1 and 2 (2026-09-17, the same Bend 2.0.5 clone, via the `~/bin/bend` wrapper)

All [V] with the verbatim message, on the JS lane unless noted.

| construct | result |
|---|---|
| `(+x, y) = r` on a pair parameter, and `match r: case Tuple{+x, y}:` | both check; the field is reusable (Base does `(a, +n) = an`) |
| a `+xs` list matched with `case _:` then used again as `xs` | checks; a `+` scrutinee survives its match |
| `case Op{t, cs, g} <> rest:`, `case _ <> t:`, `case Bin{bits, count} <> Nil{}:` | nested cons patterns check (Base and the demos use them) |
| `match c:` on a variable bound by an enclosing cons pattern | checks; Base nests `match m:` under `case 1n+np:` the same way |
| `(a, b, c) = r` and `(a, b, c)` for `A & B & C` | check |
| `List.for_each(~&2, ~U32, ~pr, xs)` with a top-level `pr`, and `"a\nb"` | check; `\n` is a newline in a string |
| a negative float literal `-0.5` | `expected : a name / observed : '0'`; keep `F32.neg` |
| a def named `count` while a pattern binds a field `count` | `expected : a pattern (a binder or a constructor) / observed : sim.count`. A pattern name that matches a top-level def is read as that def, so binders must not share a name with any def in the file |
| `Nat.show(65536n)`, and `10000n` | `Error: the machine stack overflowed (a deep recursion, or a literal too large to expand)` at check time, in 0.06 s, on both lanes (the native build checks first). `4096n` is fine. `U32.to_nat(65536)` prints 65536. Nat literals are expanded in unary: build large counts from a U32 at run time |
| a 65536-deep non-tail recursion (`1 <> mk(j)`) with the depth from `U32.to_nat` | `bend: memory fault (machine stack overflow?)` on the JS lane after 0.17 s. Any walk over a shot-length list must be a tail call; `unifs`, `lows`, `highs` and `tally` in sim.bend are accumulator loops for this reason |
| an affine tree dropped without being matched (native, 64 rounds of a 2^20-leaf tree, half discarded each round) | max RSS 18.5 MB, identical to consuming both halves, so dropped values are freed; `project` splices in `zeros(p)` and `shots` prunes empty subtrees without a leak |
| JS lane against the native binary on every line main.bend prints, histograms included | byte-identical (17 lines) |
| `case A.C{a, b}:` on a parameter of an imported type, and `~G.h` as a template argument through an alias | both check (phase 3, main.bend show3.leaf and grover_p) |
| a nested tuple literal of eight `A.C{..}` leaves returned as `S.Q(3n)` | checks: the family is normalized to the pair shape at the literal |
| `List.replicate(List<&2, S.Op>, k, xs)` with a type expression as the erased argument, and `List.concat(&2, S.Op, [a, [b], c])` | check |
| `case 1n+j:` with `j` in both `f(j)` and the recursive call (circuits.each) | `expected : j / observed : j (consumed more than once)`; `1n++j` as the plan's table says |
| `F32.show(F32.neg(0.0))` inside `C.show` on a random circuit (phase 4) | prints `-0`, and `F32.is_lt(-0.0, 0.0)` is False, so the amplitude came out as `0+-0i`. A product of two negative reals leaves an imaginary part of -0. `C.show` now adds 0.0 to each component first, which IEEE arithmetic maps to +0 on both lanes |

Statistical checks of the sampler, not pinned: 65536 shots of `RY(0.7)|0> (x) Bell(1, 2)` from seed 987654321 gave 28945, 28880, 3850, 3861 against expectations of 28914 (sigma 127) and 3854 (sigma 60), so the uniform rescaling at a generic threshold (cos^2 0.35 = 0.882) is unbiased to within a third of a sigma.

Differential test (phase 4, `uv run ref.py`): random 5-qubit circuits over every constructor in circuits.bend (named gates, P/RX/RY/RZ with F32-rounded angles, CX, CZ, CP, swap, CCX, and `ctrl` with one to three controls on named gates and on Haar-random 2x2 unitaries) against a float64 numpy reference with the same big-endian convention. 20 circuits of 40 gates: worst |bend - numpy| 9.5e-8, norms within 3e-7 of 1. 10 further circuits built natively as well: the native binary and the JS lane agreed to the bit on every amplitude, so no last-bit difference between the two lowerings' cos and sin showed up on these seeds. 5 circuits of 200 gates: worst 1.5e-7, norm down to 0.9999995. The tolerance is 1e-5; a native build costs about 3.5 s per circuit against 0.1 s for the JS lane.

## Findings from phase 5 (laws and proofs)

- A proof def is a live region: `match xs` on a `-xs` parameter fails with `a live scrutinee (a - scrutinee matches only in a dead region)`. Erased parameters may be passed to erased parameters and used in types and motives, but never matched or passed to a live parameter. So a linear (`Type`-kinded) value can appear in at most one live position of a proof, which is why the probability tree `W(n)` became `Data` (the `Sigma<&2, &2, ..>` spelling) before `shots_total` could name a subtree in both the histogram term and the induction hypothesis. [V]
- `%e : P` with `e : {a == b : T}` folds the right side into the left: the `_` in `P` marks occurrences of `b`, which become `a`. Every helper lemma is therefore stated with the term its callers eliminate on the right, e.g. `{d == List.length(..rots(d, ..))}` and `{Nat.add(length(xs), length(ys)) == length(append(xs, ys))}`. Stated the other way round, the rewrite goes in the wrong direction and needs `Equal.sym`. [V, from the demos and PROOF.bend]
- An induction hypothesis whose type already is the goal is returned directly (`Laws.run_append(n, rest, ys, apply(..))`); a three-scrutinee `match n k b:` refines the goal on all three; `(+c, lr) = w` on a `for +w` parameter and `(+l, +r) = lr` hand out reusable halves. [V]
- Negative controls for the gate, all rejected as they must be: a false law proven by `{==}` (`expected : 0n / observed : 1n`), a `?TODO` proof and an open law (both `1 TODO found`, exit 1). `bend LAWS.bend` alone reports one TODO per law, since the claims are filled by PROOF.bend. [V]
- The 18 laws of the first pass (gates, roles, measurement, circuit sizes) checked on the first attempt; the shots_total tower was the only one needing a design change. [V]

## Findings from phase 6 (native benchmarks)

- A concrete state type at a large qubit count must never reach the checker. `main` calling `S.run(20n, ..)` directly makes the checker compute `S.Q(20n)`, a pair type with 2^20 leaves: the 20-qubit build dies with `the machine stack overflowed (a deep recursion, or a literal too large to expand)` and the 24-qubit build runs the checker for ten minutes at 14 GB before it was killed. The fix, and the rule for any caller, is the prototype's shape: a function with `+n: Nat` whose result type mentions no `Q(n)`, called from `main` with the literal. `bench.bend` and `bench_sample.bend` do this. Small sizes are fine: `main.bend` uses `S.Q(3n)` in signatures. [V]
- The benchmark numbers of this phase were taken with other work on the machine (load average 10 to 15 on 18 cores: two `qutip-trap` Python jobs, Spotlight indexing and an endpoint agent), and `prototype/qbench.bend` rebuilt at 24 qubits and 2 layers ran 9.45 s on one thread and 3.06 s on all cores under that load, against the 3.52 s and 0.49 s the plan recorded on a quiet machine. The real code under the same load: 12.2 s and 3.35 s, so within about 30% on one thread and 10% on all cores of the prototype. [V]
- The sweep (`./bench.sh`, layers of H on every qubit, native, no `!`, under the load described above): 20 qubits / 100 gates 1.86 s on one thread and 0.34 s on all cores at 34 MB; 24 / 48: 10.4 to 12.2 s and 3.3 s at 514 MB; 26 / 52: 41.5 s and 17.7 s at 2050 MB; 28 / 56: 142 s and 60 s at 8194 MB; 29 / 29: 67.6 s on all cores at 16391 MB; 30 / 30: 118.8 s on all cores at 32775 MB. Memory is 32 bytes per amplitude at every size with no higher peak during a pass. No fail-stop at any size: the host reserves 8 TiB with MAP_NORESERVE and commits pages as it goes (`comp.ts` around line 5069), so the ceiling is physical memory, 30 qubits on 48 GB. Sampling 10,000 shots at 24 qubits: 6.79 s on one thread and 1.75 s on all cores including the 24 H gates, 9997 distinct bins. [V]
- The norm printed after an even number of H layers is 0.99999976 at every size, not (1 - 6e-8)^gates: the drift of the 1/sqrt2 literal is rounded away as often as it compounds. [V]

## Findings from phase 7

- Constructor names are global across the import graph: `GT{}` in a new enum fails with `duplicate declaration: GT`, because Base's `Cmp` declares it. `Kind` is a keyword and cannot name a type; `Word` is Base's bit-vector family and is best avoided as a constructor name. [V]
- `Nat.add`, `sub`, `mul`, `double`, `cmp`, `is_lt` and `divmod` are compiler intrinsics on machine words with a 2^48 overflow check (comp.ts `nat_add` and friends); `Nat.pow` and `Nat.mod` are Base defs over them. A difference of two Nats is therefore a fast exact integer, and every operation on it is componentwise, which keeps the exact amplitude laws structural. [V]
- The sampler's PRNG: the expression example of the QASM reader printed 319 shots in a bin whose probability gives 257 with sigma 16. A Python replica of the sampler with the same xorshift32 stream and the same F32 routing reproduced Bend's counts exactly, so the sampler does what it says; counting the raw stream directly gave the same 319 below 0.0627, so the deviation was in the stream; routing 200 batches of independent uniforms through the same fractions gave unbiased means, so the routing is sound. Over 300 random seeds, raw xorshift32 failed an eight-bin chi-square at 4096 draws in 4.0% of seeds at p < 0.05 and 0.7% at p < 0.01 with uniformly spread p-values, which is what a random stream does: the default seed's first 4096 outputs are a 1-in-300 outlier (p = 0.003) for that partition, not a defect. The hash finalizer from the prototype (`mix32`, verified in prototype/rng.bend) was added to `unif` anyway, since raw xorshift32 output is a linear function of its state and the finalizer costs two multiplies per uniform; every pinned histogram changed and was re-read against its expectation (all within about one sigma). [V]
- The exact scalar module fits behind the same interface as the F32 one for everything but renormalization: 1/sqrt(p) has no exact form, so `C.scale` multiplies by the F32's exact dyadic value read off its bits, and the integers grow by the 24-bit mantissa each time; exact runs should project and read ratios instead of calling `measure`. The exact build is generated by test.sh (sim_x.bend, circuits_x.bend) from the same sources with one import line changed, checks, and agrees with an independent Python D[w] reference exactly on 20 circuits of 40 gates and 5 of 200 (denominator exponents to 10), on both lanes. [V]
- Nine exact amplitude laws (X, Y, Z self-inverse; S and Sdg, T and Tdg inverse; S^4 and T^8 identity) check on the first attempt once an amplitude and its four integers are taken apart: eight rotations or two negations then compute back to the input. H H = I is not structural (it needs the reduction and cancellation of Nat sums) and is not claimed. A tree-level "gate twice is the identity" law is blocked by the same linearity that shots_total met: the Targ case needs a subtree in two live positions. [V]
- The two-qubit walk (apply4, mix4a, mix4b) agrees with numpy on random Haar 4x4 unitaries with up to two controls in either target order, worst 1.0e-7 over 20 circuits of 40 gates; the same gate type gives the exact build exact two-qubit gates (iSWAP demo). [V]
- A parser in Bend: mutual recursion is forbidden, so recursive descent is out; the QASM reader uses a character-class table so the lexer can match on the class, a state record threaded through one self-recursive loop (the List.merge.go shape), and a shunting-yard evaluator whose pop decision is a two-scrutinee match on the operator constructors rather than a computed comparison. Variable names `lambda` and `pi` are fine as parameters; `as` was avoided. [V]
- The flat-leaf hybrid (phase 7b). Base's `Array<T>` is a binary tree in the source (`ALeaf`/`ANode`) but one flat block in the runtime (comp.ts: "An Array is a block"), and `Array.get`/`set` are intrinsics. A probe block of 2^24 amplitudes as 2^25 F32s ran 24 H gates in 0.23 s of CPU on one thread at 136 MB against the tree's 1.58 s at 514 MB on the same quiet machine: about 0.6 ns per amplitude and gate, and 8 bytes per amplitude (the F32 elements are stored as 32-bit words). `flat.bend` then builds the hybrid: a tree of depth m over blocks of 2^lb amplitudes, the sim.bend walk above the blocks, a two-block elementwise loop where the walk would touch two amplitudes, and an index-and-mask loop for a target inside a block. Measured back to back with the tree on a machine at load average about 7: 4.5 to 5x faster on one thread, 3.4 to 4.8x on all cores, exactly 4x less memory at every size from 20 to 28 qubits; 30 qubits with one layer took 55 s on one thread and 10.1 s on all cores at 8.19 GB. flat_test.bend agrees with the tree to 1e-6 on circuits with targets and controls above and inside the blocks, the QFT, and a 4x4 through the tree round trip. [V]
- Loops over an array in Bend: every read hands the array back beside the element, so a kernel is a chain of helper defs each destructuring one read, and a loop that must continue after a read carries the read as its own parameter (the norm loop, the List.merge.go shape); a helper that calls the loop back is rejected as `expected : a defined name`, since definitions must precede their uses and mutual recursion is forbidden either way. [V]
- The GPU path: a hybrid binary with its top call marked `!` builds a 900 KB Metal program and runs the array kernels on the device with the same result as the CPU lane, so arrays are device-representable. It is slower: 0.90 s against 0.18 s at 24 qubits, 3.35 s against 1.22 s at 26, 14.5 s against 4.6 s at 28 with `--gpu 8GB`. One task per block with a sequential loop inside leaves the device underused; a device-friendly kernel would parallelize inside the blocks. [V]
