# Plan: a short, simple, complete, correct quantum circuit simulator in Bend 2

Written 2026-09-17 against Bend 2.0.5, the day it launched. Companion to `bend-notes.md`. Evidence markers: [V] verified by running it here this session (by me or a subagent I directed; the file is named), [R] read in a primary source, [A] measured or sourced by the research subagent in `research/sim-design-research.md` and not re-run by me.

## 1. Decision

Build a state-vector simulator whose state is a perfect binary tree of complex F32 amplitudes, indexed by qubit count at the type level; whose gates are one generic tree walk driven by a per-qubit role list (skip, control, target); whose measurement and sampling are tree folds; and whose correctness is split three ways: shape and totality by the type checker, structural laws proven in `PROOF.bend`, numerics by golden and differential tests. An exact Clifford+T amplitude module is the optional later phase that makes laws about amplitudes provable.

What is already true today [V]:

- The core (state family, gate walk, Bell state) checks and runs on the JS backend in 154 lines: `prototype/q.bend`.
- Control above the target, control below the target, two controls (Toffoli), and a role list shorter than the qubit count all give the exact expected amplitudes: `prototype/qctrl.bend`, `prototype/qccz.bend`.
- Two laws are proven, "empty role list is the identity" and "all-skip role list is the identity": `prototype/laws.bend` prints `All terms check.`
- Native build: 4.1 ns per amplitude per gate on one thread, 7x to 9x faster on 18 threads, 32 bytes per amplitude, 539 MB at 24 qubits: `prototype/qbench.bend`.
- The Metal GPU lane is 37x slower than one CPU thread on this workload. Nothing will be marked `!`.
- xorshift32, U32 to uniform F32, `F32.sqrt`, `F32.sin`, `F32.cos`, `F32.pi` all exist and work: `prototype/rng.bend`.

Size target: 350 to 450 lines of Bend for everything through sampling, plus 100 to 150 for laws and proofs, plus demos. MicroQiskit, the smallest simulator that meets the same feature bar, is 249 lines of Python [A]; the multiplier is Bend's mandatory annotations, hand-rolled complex arithmetic and PRNG, and `match` in place of `if`.

## 2. What "complete" and "correct" mean here

Complete: the feature floor that every small simulator either meets or gets caught missing [A].

1. 2^n amplitudes initialised to |0..0>
2. any single-qubit unitary on any qubit, named or as a raw 2x2
3. controlled gates with any number of controls, control above or below the target (most tiny simulators do CNOT only)
4. measurement of one qubit with real collapse, usable mid-circuit
5. shot sampling to a histogram of bitstrings
6. amplitude and probability readout, and Z expectation values (three lines, so included)
7. O(2^n) work per gate, never a Kronecker product

Out of scope, stated up front: OpenQASM parsing, density matrices and noise, gate fusion, and arbitrary two-qubit 4x4 unitaries as primitives (SWAP is three CNOTs; a general `mix4` is a later extension).

Correct, in decreasing order of strength:

1. By the checker, with no proof text: `apply : Q(n) -> Q(n)` cannot change the qubit count or the shape; every function is total by structural recursion on the depth; no `@unsafe` anywhere.
2. Laws proven in `PROOF.bend`: the structural ones in section 6.
3. Golden tests: analytic amplitudes for Bell, GHZ, Toffoli, QFT, Grover, teleportation, pinned as `#|` lines the way Bend's own tests do.
4. Differential test: random 5-qubit circuits over the full gate set compared against a short numpy reference to 1e-5.
5. Numerically sound by construction: every reduction over the state is a tree fold, which is pairwise summation. A naive left-to-right F32 sum of 2^24 probabilities is 2.3% wrong; the tree fold lands on exactly 1.0 [A]. The idiomatic Bend shape is also the numerically right one.

Not correct in Bend's sense, and impossible with F32: unitarity, norm preservation, H.H = I, X.X = I, T^8 = I. Every F32 primitive in Base is a `law` with no body [V], so nothing about floats is provable. Those become provable only with the exact ring of section 8.

## 3. Design

### 3.1 State

```python
type C is Data:
  C{re: F32, im: F32}

def Q(n: Nat) -> Type:
  match n:
    case 0n:
      C
    case 1n++p:
      Q(p) & Q(p)
```

- The root splits on qubit 0, the most significant bit; the left child is qubit 0 = |0>. Bitstrings print root to leaf, so `011` means q0=0, q1=1, q2=1. This is the Cirq and QuTiP order, the reverse of Qiskit's.
- `Q(n)` is a type-level function, not a datatype: no Node or Leaf constructor, no impossible branch to fill with junk, and a value of `Q(n)` has exactly 2^n leaves by construction. `match n` refines it: in the `0n` arm the state is a `C`, in the `1n++p` arm it destructures as a pair [V].
- The state is linear (`Type`-kinded) and consumed exactly once per pass, which lets the runtime free each node as it is matched, with no reference counts. A copyable `Data`-kinded tree is possible with the spelling `Sigma<&2, &2, Q(p), _ => Q(p)>` [V] but v1 does not need one.
- Memory: 32 bytes per amplitude natively [V], consistent with a 16-byte leaf plus 16 bytes of interior pair per leaf. On the JS backend it is about 2 KB per amplitude [A], so the JS backend is for development at 16 qubits or fewer.
- The same tree is the AutoQ/LSTA state representation from the automata-verification literature and the uncompressed form of a QMDD [A]. No novelty is claimed for the structure; what is new is fusing it with dependent types and affinity.

Why not the alternatives:

- Flat `Array<F32>`: index arithmetic with bit masks, `match` cannot inspect a computed bit so every branch needs a helper, the `a[i]` sugar covers `Array<U32>` only, and nothing about the shape lives in the type. It would be roughly 4x faster per amplitude and 4x smaller, so it is the right optimization if the tree becomes the bottleneck, as a hybrid with the tree on top and flat blocks at the leaves.
- Decision diagrams (QMDD): the whole win is a global hash-consing table plus memo caches, which is shared mutable state across threads. Bend offers that only as experimental `@unsafe` atomics, and the proof story would die with it [A].

### 3.2 Gates

```python
type Role is Data:
  Skip{}
  Ctrl{}
  Targ{}

type Gate is Data:
  Gate{a: C, b: C, c: C, d: C}     # the matrix [[a, b], [c, d]]
```

One walk applies every gate. The role list has one entry per qubit from the root; a list that ends early means "skip the rest".

- `apply(n, rs, g, q)`: above the target. `Skip` recurses into both halves in a parallel let; `Ctrl` recurses into the |1> half only and returns the |0> half untouched; `Targ` hands the two halves to `mix`.
- `mix(n, rs, g, l, r) -> Q(n) & Q(n)`: below the target, holding the |0> and |1> subtrees. `Skip` zips pairwise into (l0, r0) and (l1, r1) in a parallel let; `Ctrl` zips only the |1> sub-halves and passes (l0, r0) through as identity; at a leaf it applies the 2x2 to the amplitude pair and returns both results at once.

The butterfly returns both new subtrees from one pass, so `l` and `r` are consumed exactly once and nothing is cloned. Control above the target is `apply`'s `Ctrl` arm; control below the target is `mix`'s `Ctrl` arm; several controls are several `Ctrl` entries; an anti-control would be one more role with the branches swapped. There is no index arithmetic and no comparison anywhere, which is where array simulators hide their bugs. The per-qubit target/control/uninvolved classification is the standard QMDD controlled-gate construction [A]; here it drives a dense traversal instead of building a matrix.

The verified core, from `prototype/q.bend` [V]:

```python
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
```

`mix.leaf`, `mix.join` and `mix.ctrl` are three-line helpers that exist because a destructuring let is a match and a match may only scrutinize a parameter (section 4). The three identical `Nil`/`Skip`/`Targ` arms of `mix` collapse to one `_ <> t` arm plus the `Nil` arm in the real code.

Role lists are never hand-written by callers. `roles(cs: List<&2, Nat>, t: Nat)` builds the list from control indices and the target, so it always holds exactly one `Targ`, and a law pins that (section 6). The prototype's silent identity on a `Targ`-less list is then unreachable from the public API. A length-indexed roles type `R(n)` was tried and does not check, because a pair nest is never `Data` and the roles must be copied at every `Skip` fork [V]; a list plus a law is the right tool.

Named gates live in the scalar module: H, X, Y, Z, S, Sdg, T, Tdg, P(phi), RX, RY, RZ, and U(a, b, c, d) for a raw matrix. `F32.cos`, `F32.sin`, `F32.sqrt` and `F32.pi` are native primitives [V], so each rotation is one line. The constant 1/sqrt2 is written once as the literal `0.70710677` and multiplied, never divided; repeated multiplication by it saturates at 2 ulp of error and does not drift [A].

### 3.3 Circuits

```python
type Op is Data:
  Op{rs: List<&2, Role>, g: Gate}

def run(n: Nat, ops: List<Op>, q: Q(n)) -> Q(n)     # a left fold of apply
```

Constructors: `h(t)`, `x(t)`, `y`, `z`, `s`, `sdg`, `t`, `tdg`, `p(phi, t)`, `rx(theta, t)`, `ry`, `rz`, `cx(c, t)`, `cz(c, t)`, `ccx(c1, c2, t)`, `cp(phi, c, t)`, `swap(a, b)` as three `cx`, and the generic `ctrl(cs, t, g)`. `qft(n)` and a Grover iteration are demo helpers in `circuits.bend`, not core.

### 3.4 Measurement

- `norm2(n, q) -> F32`: parallel tree fold of |amp|^2, used when the state is finished with.
- `prob1(n, k, q) -> F32 & Q(n)`: probability that qubit k reads 1, returned beside the rebuilt state. The state is linear and a fold would consume it, so every reduction that must keep the state hands it back beside the value, which is Base's own idiom for array reads.
- `project(n, k, b, q) -> Q(n)`: replace the branch for the outcome other than b at depth k with `zeros(p)`. Purely structural, so laws about it are provable.
- `rescale(n, s, q) -> Q(n)`: multiply every amplitude by s.
- `measure(n, k, u, q) -> Bool & Q(n)`: `prob1`, compare with the uniform u, `project`, `rescale` by 1/sqrt(p). Renormalize here and nowhere else: periodic renormalization removes only about 8% of accumulated error and hides the norm drift that reveals bugs [A].
- `expect_z(n, k, q) -> F32 & Q(n)`, which is 1 - 2 p1.

### 3.5 Sampling

- PRNG: xorshift32 over `+U32`, since Base has no random effect and no hex literals [V]. `unif(x) = F32.mul(U32.to_f32(x >> 8n), 5.9604645e-8)` gives an exact 24-bit uniform in [0, 1) [V]. The default seed is fixed so histograms are reproducible and golden-testable; `IO.now()` is the opt-in seed.
- `sums(n, q) -> S(n)`: a probability tree with the subtree total stored at every node, one pass.
- `shots(n, us: List<&2, F32>, s: S(n)) -> List<Bin>` with `type Bin is Data: Bin{bits: String, count: Nat}`: route the list of uniforms down the tree. At each node, split the list at the threshold left/total, rescale each side back into [0, 1), recurse into both sides in a parallel let, and stop at any node whose list is empty. A leaf returns one `Bin`; appending the left and right results yields the histogram already in bitstring order. Cost is O(2^n + shots * n) at worst, with automatic pruning of unpopulated subtrees, and no binomial sampler. This is the sorted-uniform form of Sanders' divide-and-conquer sampling [A].
- Fallback if the list splitting fights the affine rules: a `Data`-kinded `S(n)` (the `Sigma<&2, &2, ...>` spelling) and one O(n) walk per shot.

### 3.6 Output

`show(n, q)` prints amplitudes root to leaf as `re+imi`, and `show_hist` prints one `bitstring count` line per bin. Every program ends with `#|` lines pinning its expected output, so the examples are the tests.

### 3.7 Parallelism

- Every recursion over the tree is a balanced parallel let, so the two forks are equal by construction and no depth cutoff is needed; none of Bend's own tree benchmarks use one [R].
- Plain parallel lets fork on the CPU without `!` [V]: 2.15 s on one thread versus 0.55 s by default for the same unmarked binary. This settles the open question in `bend-notes.md` about issue #767.
- Nothing is marked `!`. At 24 qubits the Metal lane took 76.8 s against 2.06 s on one CPU thread and 0.55 s on 18 [V]. A pointer-chasing tree walk is the "divergent work" the guide says stays on the CPU; a GPU path would need the flat-leaf hybrid of 3.1. A second reason: any `!` region that touches `F32.show` or `++` fails at run time with "a function the device does not hold", and only after the device work has finished [V].
- Build with `bend main.bend -o sim` and run `./sim --threads N`. The JS backend, `bend main.bend`, is for development at small n.

### 3.8 Module boundary

`sim.bend` uses the scalar only through `C`, `Gate`, `C.add`, `C.mul`, `C.scale`, `C.zero`, `C.one`, `C.norm2 -> F32`, `C.show`. Everything about F32 lives in `amp.bend`. The exact ring of section 8 is then a second `amp` module selected by one import line, with no templates threaded through the core.

## 4. Verified facts and idioms the code must follow

All [V] unless marked; verbatim checker errors are in `research/bend-findings.md`.

| rule | why |
|---|---|
| The shrinking `Nat` is the first parameter of every recursive def | the termination check reads arguments left to right |
| Write `case 1n++p:` whenever `p` is used twice | `1n+p` binds `p` affinely; the error is `p (consumed more than once)` |
| A pair returned by a call or by a parallel let is taken apart by a helper def that destructures its own parameter (`mix.join`, `mix.ctrl`) | a destructuring let is a match, and a match may only scrutinize a parameter or a pattern-bound variable, never a computed value or a local binder |
| A parallel let binds plain names only: `a b = f(x) g(y)` | patterns on its left side are rejected |
| Reusing a leaf twice needs the annotation `+x = {l : C}` | `+x = l` fails with `expected : Data / observed : Type`, because `Q(0n)` is not syntactically `C` |
| Any `U32`, `F32`, `Nat` or list used twice is a `+` binder | affinity applies to machine words too |
| Match on the role before destructuring the subtrees | scrutinees must appear in binder order [A] |
| Constants are literals: `0.70710677`, `5.9604645e-8`; negatives through `F32.neg` until a negative literal is tried | float literals parse; there are no hex literals |
| Operators carry their type: `(x .^. (x << 13n) : U32)` | untyped operators mean `Nat` |
| Strings are built on the host, never inside a `!` region | see 3.7 |
| Erased `-x` parameters are never used live | `expected : -n / observed : n` |
| A `def T(n: Nat) -> Data` family needs `Sigma<&2, &2, A, _ => B>` for its pairs | `A & B` is always `Kind(&1)` |
| Laws: induction on `n`, destructure `q` in the step case, rewrite with the hypothesis, finish with `{==}` | `prototype/laws.bend` |

## 5. Performance envelope on this machine (M5 Pro, 18 cores, 48 GB)

Measured with `prototype/qbench.bend`: layers of H on every qubit, native, no `!` [V].

| circuit | 1 thread | 4 threads | 18 threads | max RSS |
|---|---|---|---|---|
| 20 qubits, 100 gates | 0.85 s | | 0.09 s | 35 MB |
| 24 qubits, 48 gates | 3.52 s | 1.08 s | 0.49 s | 539 MB |

Derived:

- 4.1 ns per amplitude per gate on one thread, about 0.6 ns on 18. A hand-written C loop over a flat array is an estimated 1 ns, so the tree costs about 4x in time and 4x in memory. Acceptable for "simple"; the flat-leaf hybrid is the escape hatch.
- Per gate at 24 qubits: 73 ms on one thread, 10 ms on 18. A 1,000-gate circuit at 24 qubits is about 10 s.
- Memory is 32 bytes per amplitude: 28 qubits is 8.6 GB and 29 is 17 GB per state, with a higher peak during a pass. Expect a ceiling of 28 or 29 qubits here, untested above 24. Two runtime fail-stops from the runtime paper are unexplored at that scale: the task count saturating at 2^24 and "block depth 31" [R].
- The JS backend is about 2 KB per amplitude and sequential [A]; use it up to 16 qubits.
- `sums` is one fold, cheaper than a gate; 10,000 shots at 24 qubits cost about one more pass.

## 6. Laws

Proven now [V], in `prototype/laws.bend`:

- `nil_id`: apply with an empty role list is the identity.
- `skip_id`: apply with all-skip roles is the identity, by induction on n.

Planned, float-free, judged feasible:

- `roles_targ`: `roles(cs, t)` has `Targ` at index t and `Ctrl` at each c. Needs list-indexing lemmas over Nat that Base lacks; `demos/proof_numerics` has `add_comm`, `add_assoc`, `mul_comm`, `mul_dist` to copy.
- `ctrl_keeps_zero`: a control leaves the |0> subtree unchanged (definitional).
- `run_append`: `run(ops1 ++ ops2, q) == run(ops2, run(ops1, q))`.
- `project_idem`: projecting twice on the same outcome equals projecting once. This is why `project` is split from `rescale`.
- `project_other_zero`: after `project(k, b)` the other branch at depth k is `zeros`.
- `shots_total`: the histogram counts sum to the number of uniforms. The split is by an F32 comparison but the count is conserved whichever way each comparison goes, so it is provable.
- `qft_gate_count`: the QFT on n qubits has n(n+1)/2 gates before swaps.

Impossible with F32, so stated in a comment rather than as unfilled `law`s (an unfilled law is an axiom for dead code): unitarity, norm preservation, H.H = I, X.X = I, T^8 = I. The exact module makes exactly these provable.

House rules from the notes: `bend PROOF.bend` exits 0 whenever `@unsafe` appears anywhere in the import graph (#776), so the codebase stays free of it; the hub rejects files with `?TODO` or unfilled laws.

## 7. Files and phases

```
quantum-simulator/
  amp.bend        scalar module: C, Gate, named gates                                  ~60 lines
  sim.bend        Q, Role, apply, mix, Op, run, norm2, prob1, project, rescale,
                  measure, sums, shots, PRNG, show                                    ~220 lines
  circuits.bend   gate constructors, swap, qft, grover                                 ~60 lines
  main.bend       demos, each ending in #| lines                                       ~60 lines
  LAWS.bend       claims                                                               ~40 lines
  PROOF.bend      proofs                                                              ~100 lines
  test.sh         run every *.bend and diff stdout against its #| lines
  ref.py          numpy differential reference, run with uv                            ~60 lines
  prototype/      today's verified smoke files, kept as evidence until superseded
  research/       API survey, smoke findings, design research report
```

Phases, each with an acceptance test:

0. Toolchain (30 min). Either the installer, `curl -fsSL https://bend-lang.com/install.sh | sh`, with `BEND_NO_TELEMETRY=1` exported in the shell rc because every run phones home otherwise [R], or keep the clone and put a `~/bin/bend` wrapper around `bun .../bend2/main.ts` (the `home-env-changes` skill covers `~/bin`). Accept: `bend --version` prints 2.0.5 and `bend prototype/q.bend` prints the Bell state.
1. Core (half a day). Split `prototype/q.bend` into `sim.bend` and `amp.bend`; add `roles`, `Op`, `run`, the full gate table. Accept: golden lines for Bell, GHZ(3), Toffoli, control-below-target, and `T^8` applied to |+> returning |+> to 1e-6.
2. Measurement and sampling (one day). `norm2`, `prob1`, `project`, `rescale`, `measure`, `sums`, `shots`, PRNG. Accept: 4,096 shots of a Bell state fall into two bins each within 96 of 2,048 (3 sigma); teleporting `RY(0.7)|0>` reproduces cos 0.35 and sin 0.35 on the target after corrections; a fixed-seed histogram pinned as golden.
3. Library and demos (half a day). `circuits.bend` with `swap`, `cp`, `qft(n)`, a Grover iteration. Accept: QFT of |001> on 3 qubits gives amplitudes (1/sqrt8) e^(2 pi i k/8); Grover with |101> marked reaches probability 0.945 after two iterations.
4. Differential test (half a day). `ref.py` generates random 5-qubit circuits over the whole gate set as both Bend source and numpy, runs both, compares amplitudes to 1e-5. This is the test that covers RX, RY, RZ and P, whose transcendentals may differ in the last bit across backends [A]; Bend needs no parser for it.
5. Laws (one to two days, the least predictable phase). `LAWS.bend` and `PROOF.bend` for section 6. Accept: `bend PROOF.bend` prints `All terms check.` with no `?TODO`.
6. Native benchmarks and README (half a day). Reproduce section 5 on the real code at 20, 24, 26 and 28 qubits; record the ceiling and any fail-stop message.
7. Optional, in order of value: (a) the exact Clifford+T scalar module and amplitude laws, section 8; (b) the tree-on-top, flat-`Array<F32>`-at-the-leaves hybrid for about 4x memory and speed and a possible GPU path; (c) `mix4` for arbitrary two-qubit unitaries; (d) an OpenQASM 2 subset reader, which will be slow because strings are linked lists, at roughly 150 lines.

## 8. The exact-arithmetic option

This is the only route to provable amplitudes. Amplitudes live in D[omega] = Z[omega][1/sqrt2]: four integers (a, b, c, d) meaning a + b omega + c omega^2 + d omega^3 with omega = e^(i pi/4), plus one denominator exponent k shared by the whole state. Every Clifford+T gate scales all amplitudes uniformly, so one global k is an invariant [A].

- Gate set: X, Y, Z, H, S, Sdg, T, Tdg, CNOT, CZ, CCZ, SWAP. No rotations.
- Arithmetic needed: add, subtract, negate, halve, parity test, and tuple rotation, since multiplying by omega is (a, b, c, d) -> (b, c, d, -a). No multiplication at all. H is the butterfly (x + y, x - y) with k + 1, and a global pass divides out sqrt2 whenever every amplitude has (a - c) and (b - d) even [A].
- Signed integers do not exist in Bend. Use the difference pair (pos, neg) of Nats, so addition is componentwise `Nat.add` and commutativity is `Nat.add_comm`, which Base ships [A].
- Bounds, both provable by induction: k is at most the number of H gates, and every coefficient is at most 2^(k/2). A 48-bit Nat therefore holds exact amplitudes through 93 H gates on any circuit, but exact probabilities only through 46; compute probabilities in F32 from the exact coefficients [A].
- Size: a reference implementation of the ring, the gates and the global reduction measured 128 lines [A]. Proofs of H.H = I and norm preservation on top are the unknown; there is no data on the proof-to-code ratio in Bend.
- Prior art to compare against: SliQSim, an exact D[omega] state-vector simulator, and AutoQ's leaf alphabet [A].

Recommendation: F32 first. It is smaller, it covers rotations, and F32 precision is not the limit at reachable depths: L2 error grows as about 0.76 sqrt(depth) u, reaching 1e-3 near depth 4e8 [A]. Do the exact module as phase 7a when the goal shifts from "a simulator" to "a simulator with proofs about amplitudes"; the module boundary of 3.8 is there so that shift costs one import line.

## 9. Decisions for you

Each has a recommendation, and the build proceeds on it unless you say otherwise.

1. Amplitudes: F32 in v1, the exact ring as phase 7a. Alternative: exact first, which drops rotations and roughly doubles the proof work before anything runs.
2. Modules: `amp.bend`, `sim.bend`, `circuits.bend` plus laws, so the scalar swap is an import line. Alternative: one file, marginally shorter, same total.
3. Renormalize only at measurement, with `project` split from `rescale` for provability. Alternative: never renormalize and report ratios, which saves a `sqrt` and a pass but leaves collapsed states printing unnormalized amplitudes.
4. Qubit order: the root is qubit 0 and the leftmost printed bit (Cirq order). Alternative: Qiskit's little-endian, which reverses the printed order relative to the tree.
5. Scope: Z expectation in, OpenQASM out. Alternative: the QASM subset reader as phase 7d.

## 10. Risks

- Compiler maturity: 13 bugs filed on launch day [R]. The C emitter had an unbound-name bug for some printed types (#789) and is quadratic in the number of sequential statements (#785); keep defs short and route all printing through `show`.
- Untested scale: nothing above 24 qubits has run; the runtime's fail-stops are documented but their triggers at this size are not [R].
- Transcendentals may differ in the last bit between the JS, C and Metal lowerings [A]; golden tests therefore use sqrt-only gates, and rotations are covered by the differential test with a tolerance.
- Proof effort is the unknown: Base ships one arithmetic law, so Nat lemmas are hand-written.
- Telemetry: an installed `bend` reports every run unless `BEND_NO_TELEMETRY=1` [R].
- Bend 2 is one day old and its author has flagged the array-read API and the quantity syntax for redesign [R]; this design uses neither.

## 11. Sources

- `bend-notes.md` in this directory, and the Bend 2.0.5 clone read this session: `bend2/base.bend`, `guide/GUIDE.md`, `bench/runtime/{tree-matmul,merkle,nbody}`, `demos/{pure_par_sum,proof_numerics}`.
- `research/bend-api.md`: verbatim Base signatures by namespace, idiom excerpts, `F32.show` formats.
- `research/bend-findings.md`: every smoke test with verbatim checker output, the timing table, the final prototype sources, and corrections to `bend-notes.md`.
- `research/sim-design-research.md`: 112 sources. The load-bearing ones: Zulehner and Wille, arXiv:1707.00865 (tree decomposition, recursive matrix-vector product); Wille, Hillmich and Burgholzer, arXiv:2108.07027 (target/control/uninvolved construction); AutoQ, arXiv:2301.07747, and LSTA, arXiv:2410.18540 (perfect-tree state, a gate as a transformation of sibling subtrees at level i); Ross and Selinger, arXiv:1403.2975, and Giles and Selinger, arXiv:1212.0506 (D[omega] and the reduction criterion); Hübschle-Schneider and Sanders, arXiv:1903.00227 (divide-and-conquer sampling); Higham and Mary, SIAM J. Sci. Comput. 2019, and Betelu, arXiv:2005.13392 (F32 error growth and the nonnegative-sum hazard); MicroQiskit, github.com/qiskit-community/MicroQiskit (the 249-line feature floor).
