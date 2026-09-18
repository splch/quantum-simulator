# Design references: a minimal, correct, complete state-vector simulator in Bend 2

Research compiled 2026-09-17. Target language: Bend 2 (released today). Companion file: `~/Repositories/quantum-simulator/bend-notes.md` (language facts, already compiled).

## Evidence markers

- **[V]** verified by running it on this machine (Bend 2.0.5 via `bun bend/bend2/main.ts`, or Python/NumPy for numerics)
- **[R]** read in a primary source I fetched (paper PDF, repo source, official docs)
- **[S]** search-result excerpt or third-party summary I could not open directly
- **[U]** UNVERIFIED - stated but not confirmed

The Bend 2 repo is cloned at `<scratchpad>/bend` (commit shipped as 2.0.5), so all Bend claims below marked [V] or [R] were checked against real source or a real run, not memory.

---

## 0. Headline findings, in order of how much they change the design

1. **The design works, today, in Bend 2, in 138 lines.** A prototype using a depth-indexed tree plus a roles list already exists in this session's scratchpad (`smoke/q.bend`) and I ran it: Bell state, **control-below-target**, control-below-target-with-an-intervening-skip, and Toffoli all produce correct amplitudes. [V] See §1.5.
2. **The tree is not just convenient, it is numerically necessary - and this is the strongest new argument for the design.** A naive left-to-right F32 sum of `|a|^2` is **2.3% wrong at n = 24**. A recursive tree fold *is* pairwise summation, with error `O(log2 N * u)` instead of `O(N * u)` - four orders of magnitude better at n = 24 - and you get it structurally, for free, with no Kahan compensation and no F64 accumulator (which Bend does not have). [V] See §7.
3. **The roles-per-level walk is not novel - it is the standard QMDD controlled-gate construction**, where every qubit is classified as *target*, *control*, or *not part of the operation*. [R] §1.3. And the perfect-binary-tree state with "gate at qubit i = a transformation on neighbouring subtrees at level i" is published verbatim in the **AutoQ / LSTA** automata papers (CAV 2023, POPL 2025). [R] §1.3b. **Claim no novelty for the data structure**; the novel part is fusing the two in a dependently typed affine language.
4. **Exact Clifford+T arithmetic is much cheaper than expected and is the only route to provable amplitudes.** For `{X,Y,Z,H,S,T,CNOT,CZ,SWAP}` you need **no multiplication at all** - add, subtract, negate, halve, parity test, and index permutation. A reference implementation is **128 lines**. The reduction condition is `(a-c)` even and `(b-d)` even (your guess, confirmed three ways). `|coeff| <= 2^(k/2)` and `k <= #H` are both *provable*. [V][R] See §3.
5. **F32 makes the amplitudes unprovable, permanently.** "F32 is axiomatic: nothing about floating point can be proven" [R]. So `X.X = id`, unitarity and norm preservation are out of reach with floats and become ordinary inductions with the exact ring. **The amplitude type decides whether this project has anything to prove.** See §1.7 and §3.
6. **Q5 is moot.** Bend 2's `base.bend` ships `F32.sqrt`, `sin`, `cos`, `exp`, `log`, `pow`, `atan2`, `hypot`, `pi` as native primitives, lowered to libm / `precise::` / `Math.*`. You do not need minimax polynomials. [V][R] See §5.
7. **F32 precision is not your limit; wall-clock and memory are.** Measured `L2 ~ 0.76 * sqrt(depth) * u`, constant to 4% over four decades, so L2 error hits 1e-3 around depth 4.6e8. The exception is *biased* error - small-angle rotations (QFT, Trotter) break the law by 20x. Probability underflow is ~80 orders of magnitude from mattering. [V] See §7.
8. **Bend 2 has no hex literals, no RNG effect, and `+` is mandatory on any binding used twice.** All three cost real code and all three are verified. [V] See §4.5.
9. **No quantum simulator exists in Bend 1, Bend 2, HVM, HVM2 or HVM3.** Clean negative across GitHub repo/code/issue search and both guides. You would be first. [R] §6.1. And **no proof assistant anywhere** types the state as a qubit-indexed tree and proves gate application by induction on it - SQIR's `f_to_vec` + `f_to_vec_split` is the closest skeleton. [R] §6.3.
10. **The FP-lineage papers you named do not use trees.** Quipper's simulator is an association list over `Map Qubit Bool` basis states; QIO is a heap plus a probability distribution. The tree comes from the decision-diagram and automata literature, not the Haskell literature. [R] §1.1-1.2.
11. **The one alarming measurement: the pair-tree costs ~1 500-2 240 bytes per amplitude on the JS backend** - 2.35 GB at n=20, 25.2 GB at n=24, a ~200x blow-up over the 8-byte ideal. Correctness was fine; this is pure representation overhead. Whether the native C backend fixes it is the top open question and is one build away. [V] See §7.

---

## 1. Tree-structured state vectors in functional quantum simulation

### 1.1 What the functional-programming lineage actually does (and it is not trees)

I checked the actual source rather than the prose, because the summaries are misleading.

**Quipper** - `QuipperLib/Simulation/QuantumSimulation.hs`, 856 lines. [R] (fetched from https://raw.githubusercontent.com/silky/quipper/master/QuipperLib/Simulation/QuantumSimulation.hs)

```haskell
-- | The type of vectors with scalars in /n/ over the basis /a/. A
-- vector is simply a list of pairs.
data Vector n a = Vector [(a,n)]

-- | An amplitude distribution gives each classical basis state an amplitude.
type Amplitudes r = Vector (Cplx r) (Map Qubit Bool)

instance (Num n) => Monad (Vector n) where
        return a = Vector [(a,1)]
        (Vector ps) >>= f = Vector [(b,i*j) | (a,i) <- ps, (b,j) <- removeVector (f a)]
```

So: a **sparse association list** of (basis state, amplitude) pairs, where a basis state is itself a `Map Qubit Bool`. The vector is a monad (the "probability/vector monad"), and gate application is `>>=`. Equal terms are combined only in `show` and in an explicit `addAmplitude`-style helper. Docs: https://www.mathstat.dal.ca/~selinger/quipper/doc/Quipper-Libraries-Simulation-QuantumSimulation.html

Consequences for you: no random access is needed (good), but the term count is unbounded, you pay a `Map` lookup per qubit per term, and you must dedupe basis states or `H^n` explodes into 2^n *unmerged* terms. There is no structural sharing and no natural parallel decomposition. This is a semantics vehicle, not a simulator architecture.

**The Quantum IO Monad** (Altenkirch & Green) - same family. A `QIO` program is interpreted either into a probability distribution or into `IO` with a random number generator; the quantum state is a **heap mapping qubits to booleans** plus amplitudes, with `Map` cited as the heap implementation. [S] (search-derived; the PDF at https://people.cs.nott.ac.uk/psztxa/publ/qio-chapter.pdf downloaded but my text extraction of it was not clean enough to quote). Chapter: https://www.cambridge.org/core/books/abs/semantic-techniques-in-quantum-computation/quantum-io-monad/1C501E5F1E9964F7B7183A18754FABE1 . Shor-in-Haskell companion: https://people.cs.nott.ac.uk/psztxa/publ/qio.pdf

**Sabry, "Modeling quantum computing in Haskell" (Haskell Workshop 2003)** - https://dl.acm.org/doi/10.1145/871895.871900 (paywalled; the IU mirror `cs.indiana.edu/~sabry/papers/quantum.pdf` now 302s to a department page [V - I fetched it and got HTML]). Search-derived claim: qubits are represented as "a dictionary that maps values to probabilities". [S][U] I could not verify the code. Its companion paper in the same proceedings is Karczmarczuk, "Structure and interpretation of quantum mechanics" (https://dl.acm.org/doi/pdf/10.1145/871895.871901). Treat Sabry 2003 as the origin of the *vector-as-monad* idea that Quipper later shipped - which I did verify - rather than as a tree reference.

**Vizzotto, Altenkirch & Sabry, "Structuring quantum effects: superoperators as arrows"** (MSCS 16(3), 2006) - https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/structuring-quantum-effects-superoperators-as-arrows/E41F502C6D7E08E70D8B7852A448D6D1 ; arXiv quant-ph/0501151 (I downloaded it). The contribution is *density matrices + superoperators split into a pure part and an effectful arrow*, i.e. how to type mixed-state computation, not how to lay out amplitudes. Companion: "Quantum arrows in Haskell", https://www.mathstat.dal.ca/~selinger/qpl2006/PDFS/10-Vizzotto-etal.pdf

**Altenkirch & Grattage, QML** - https://arxiv.org/pdf/quant-ph/0409065 (downloaded). A *language design* with a linear/affine type system distinguishing classical from quantum control, compiled to circuits. Relevant to you as precedent that affine typing and quantum data fit together; not a state-vector layout. Haskell implementation overview: https://arxiv.org/pdf/0806.2735

**Bottom line for Q1's first half:** none of the five named sources gives you a tree. If you want a citation for the tree, cite the decision-diagram literature.

### 1.2 The tree formulation, from a primary source

**Zulehner & Wille, "Advanced Simulation of Quantum Computations"** (IEEE TCAD; arXiv:1707.00865v3) - https://arxiv.org/pdf/1707.00865 [R] (downloaded and read)

The decomposition convention, verbatim:

> "consider a quantum system with qubits q0, q1, ... qn-1, whereby q0 represents the most significant qubit. Then, the first 2^(n-1) entries of the corresponding state vector represent the amplitudes for the basis states with q0 set to |0>; the other entries represent the amplitudes for states with q0 set to |1>. This decomposition is represented in a decision diagram structure by a node labeled q0 and two successors leading to nodes representing the sub-vectors. The sub-vectors are recursively decomposed further until vectors of size 1 (i.e. a complex number) results."

**So: root = most significant qubit, left child = that qubit is |0>, right child = |1>, leaves are amplitudes.** That is exactly a perfect binary tree of depth n, which is also exactly what Bend's `Array<T>` is internally ("Internally an array is a perfect binary tree" - `bend-notes.md`, from GUIDE.md [R]).

Matrix-vector product, verbatim:

> "U . psi = [[U00, U01], [U10, U11]] . [psi0; psi1] = [U00 . psi0; U10 . psi0] + [U01 . psi1; U11 . psi1]
> This means, that we have to recursively determine the four sub-products U00.psi0, U01.psi1, U10.psi0, and U11.psi1."

and addition:

> "psi + phi = [psi0; phi0] + ... = [psi0 + phi0; psi1 + phi1]"

i.e. `psi'_0 = U00.psi0 + U01.psi1`, `psi'_1 = U10.psi0 + U11.psi1`, recursively. Four sub-products and two sub-sums per level. **This is a 4-way balanced fork** - the single parallel idiom Bend has.

The 4-qubit-matrix version: a 2^n x 2^n matrix decomposes into **four** sub-matrices per level ("All entries in the left upper sub-matrix (right lower sub-matrix) provide the values describing the mapping from basis states |i> to |j> with both assuming q0 = |0> (q0 = |1>)").

The key efficiency observation, also verbatim, is about the identity:

> "All that has to be done to determine A (x) B is replacing A's terminal with the root node of B."

i.e. `H (x) I2` in DD form is just H's DD with its terminal replaced by I2's root. **The identity factor is structurally free.** That is the license for specializing the recursion: at any level where the gate acts as identity, the matrix-vector recursion degenerates to "recurse into both halves independently", and you never build the matrix at all.

### 1.3 "Roles per level: skip / control / target" is a known formulation

Yes. It is the standard QMDD construction for controlled operations.

**Wille, Hillmich & Burgholzer, "Tools for Quantum Computing Based on Decision Diagrams"**, ACM Transactions on Quantum Computing 3(3), Article 13, 2022. DOI https://doi.org/10.1145/3491246 ; open arXiv version https://arxiv.org/abs/2108.07027 (the ACM `fullHtml` URL returns HTTP 403 to automated fetches [V]).

The description [S - from the indexed text of that page; I could not open ACM DL directly, so treat the wording as close paraphrase rather than verbatim]:

> The construction of decision diagrams for operations with arbitrary controls is performed in a bottom-up fashion from qubit q0 to qn-1, where **each qubit is either the target qubit, a control qubit, or not part of the operation**. For the target qubit, a node with edges holding the operation values is created; for control qubits, edges representing the mapped operation point towards the operation while remaining edges point to the identity operation. For qubits not part of the operation, the corresponding edges represent the identity operation on those qubits.

That is your three roles exactly: `Targ` / `Ctrl` / `Skip`. Supporting statements from the MQT Core docs (https://mqt.readthedocs.io/projects/core/en/latest/dd_package.html [R]): the recursive multiply is given as equation (6) in the same `U|psi>` block form as above, and "controlled quantum gates with arbitrarily many controls (such as the multi-controlled Toffoli gate) give rise to decision diagrams with a linear number of nodes".

**What is arguably yours:** *fusing* that per-level role classification directly into a dense-tree traversal, so no matrix object is ever materialised and no hash-consing table is needed. I found no paper presenting it that way. Mark it "a specialization of a known construction", not a new algorithm.

Related tutorial (2025, may be a gentler citation): "A tutorial on applying quantum multiple-valued decision diagrams to circuit simulation", https://link.springer.com/article/10.1007/s11128-025-04917-0

### 1.3b The closest formalized prior art: AutoQ and level-synchronized tree automata

This is the nearest thing to your exact design in the literature, and it is **not** from the DD world or the dependent-types world - it is from automata theory.

**AutoQ** (CAV 2023), https://arxiv.org/pdf/2301.07747 - verbatim:

> "a path from a root to a leaf ... in such a tree corresponds to one computational basis state (e.g. |0000> or |0101> for a four-qubit circuit), and the corresponding leaf represents the complex amplitude of [it]"

A gate at qubit `t` is applied by **descending to level `x_t` and transforming sibling subtrees pairwise** (their Algorithms 1-4). Amplitudes are **not floats**: they live in a finite alphabet over `Z^5` - an exact algebraic encoding with `sqrt(2)` factored out, where "the only possibility of changing the k part of a leaf symbol is the multiplication with 1/sqrt(2)". That is the same exact-ring idea as §3.

**AutoQ 2.0 / level-synchronized tree automata (LSTA)** (POPL 2025), https://arxiv.org/html/2410.18540v1 , https://dl.acm.org/doi/10.1145/3704868 - verbatim:

> "The tree is perfect, i.e., the length of every branch is the same and equals the number of qubits."

and a single-qubit gate `U` on qubit `i`

> "corresponds to a tree transformation on every two neighboring subtrees at level i"

**That is precisely your operational semantics, stated in a peer-reviewed paper.** They prove succinctness (a `2^n`-state set in `O(n)` transitions), emptiness PSPACE-complete, entailment decidable, and closure under union/intersection (not complementation). Also relevant: "Parameterized Verification of Quantum Circuits", https://arxiv.org/pdf/2511.19897

**Use this as your citation for the representation itself**, with QMDD (§1.8) as the compressed engineering relative and the Wille et al. role classification (§1.3) as the citation for the gate-construction walk. Between them, essentially every piece of your design has a published antecedent - which is good news for writing it up, and means you should not claim novelty for the data structure.

### 1.4 Why the role walk solves the control-above-vs-below-target problem for free

This is the crux, so stated plainly.

In an array simulator you apply a single-qubit gate at qubit k by pairing amplitudes whose indices differ only in bit k. For a controlled gate you additionally mask on the control bit. The index arithmetic changes depending on whether control < target or control > target, which is where bugs live.

In the role walk there is **no index arithmetic and no comparison at all**. You walk the tree top-down, consuming one role per level, in qubit order. Two mutually recursive-in-spirit (but in Bend, two separate) functions:

- `apply` - you have not yet reached the target. At `Skip`, recurse into both halves. At `Ctrl`, recurse into the `|1>` half only and return the `|0>` half untouched. At `Targ`, hand the two halves to `mix`.
- `mix` - you are *below* the target and hold its two half-trees `l` and `r`, which must be combined by the 2x2. At `Skip`, recurse pairwise into `(l0,r0)` and `(l1,r1)`. At `Ctrl`, recurse pairwise into the `|1>` sub-halves only, and pass the `|0>` sub-halves through *as identity* (`l0` stays in the first output, `r0` in the second). At a leaf, apply the 2x2 to the amplitude pair.

Control above target is handled by `apply`'s `Ctrl`; control below target is handled by `mix`'s `Ctrl`. Same code path for both orders, same code path for arbitrarily many controls, intervening skips anywhere. Anti-controls (control on `|0>`) are one more role with the branches swapped.

Cost: each amplitude is touched exactly once. The role list is `Data` and gets duplicated at every `Skip` fork, but the total duplication work is `sum over levels l of 2^l * (d - l) = O(2^d)`, so it is a constant factor, not an extra `d`.

### 1.5 The verified Bend 2 implementation

`<scratchpad>/smoke/q.bend`, 138 lines, written in an earlier session; **I ran it and it is correct** [V].

The type is the load-bearing choice - a depth-indexed *type-level function*, not a datatype:

```python
def Q(n: Nat) -> Type:
  match n:
    case 0n:
      C                 # C is the complex amplitude record
    case 1n++p:
      Q(p) & Q(p)       # a pair of subtrees
```

`Q(n)` is a nested pair tree of exactly 2^n amplitudes. It is a perfect binary tree **by construction**: there is no `Leaf | Node` choice, so there are no impossible cases to match and totality is free. Bend's checker reduces `Q(0n)` to `C` and `Q(1n+p)` to `Q(p) & Q(p)` during case refinement, which is what makes this work [V - it type-checked and ran].

The gate walk (abridged from the file; the real one also has `mix.join` and `mix.ctrl` helpers, because `match` may only scrutinise a parameter, so pair results have to be passed into a helper to be destructured):

```python
type Role is Data:
  Skip{}
  Ctrl{}
  Targ{}

def apply(n: Nat, +rs: List<&2, Role>, +g: Gate, q: Q(n)) -> Q(n):
  match n rs:
    case 0n _:                 q
    case 1n++p Nil{}:          q
    case 1n++p Skip{} <> t:
      (l, r) = q
      a b = apply(p, t, g, l) apply(p, t, g, r)     # balanced fork
      (a, b)
    case 1n++p Ctrl{} <> t:
      (l, r) = q
      (l, apply(p, t, g, r))                        # |0> half untouched
    case 1n++p Targ{} <> t:
      (l, r) = q
      mix(p, t, g, l, r)

def mix(n: Nat, +rs: List<&2, Role>, +g: Gate, l: Q(n), r: Q(n)) -> Q(n) & Q(n):
  match n rs:
    case 0n _:                 mix.leaf(g, l, r)    # (a*x+b*y, c*x+d*y)
    case 1n++p Ctrl{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      mix.ctrl(p, l0, r0, mix(p, t, g, l1, r1))     # control BELOW target
    case 1n++p Skip{} <> t:
      (l0, l1) = l
      (r0, r1) = r
      a b = mix(p, t, g, l0, r0) mix(p, t, g, l1, r1)
      mix.join(p, a, b)
    ...
```

**Verified runs** [V], all three on Bend 2.0.5 via the JS backend:

| case | roles | expected | got |
|---|---|---|---|
| H on q0, then CNOT ctrl=q0 targ=q1 | `[Targ,Skip]` then `[Ctrl,Targ]` | .707, 0, 0, .707 | `0.70710677 0 0 0.70710677` |
| H on q1, then CNOT **ctrl=q1 targ=q0** | `[Skip,Targ]` then `[Targ,Ctrl]` | .707 at 00 and 11 | `0.70710677 0 0 0.70710677` |
| 3q: H on q2, then CNOT **ctrl=q2 targ=q0** with a Skip between | `[Targ,Skip,Ctrl]` | .707 at idx 0, 5 | `.707 0 0 0 0 .707 0 0` |
| 3q Toffoli: H on q0, H on q1, then CCX | `[Ctrl,Ctrl,Targ]` | .5 at idx 0,2,4,7 | `.5 0 .5 0 .5 0 0 .5` (as `0.49999997`) |

Control-below-target and multi-control both work with no special casing. The `0.49999997` is the correct F32 answer, not a bug - see §7.

### 1.6 Compare against Bend 2's own tree matrix benchmark - and prefer the indexed type

Bend 2 ships `bench/runtime/tree-matmul/main.bend`, 180 lines [R - read locally]. It does block-recursive matrix-vector product on exactly this shape, but with **datatypes** instead of an indexed type:

```python
type Mat is Data:
  Lf{v: U32}
  Qd{a: Mat, b: Mat, c: Mat, d: Mat}

type Vec is Data:
  Vl{v: U32}
  Vn{l: Vec, r: Vec}

# [[a,b],[c,d]] * (l,h) = (a*l + b*h, c*l + d*h)
def mvm(m: Mat, +v: Vec) -> Vec:
  match m v:
    case Lf{x} Vl{y}:          Vl{U32.mul(x, y)}
    case Lf{x} Vn{l, h}:       Vl{0}        # <-- junk: impossible case
    case Qd{a, b, c, d} Vl{y}: Vl{0}        # <-- junk: impossible case
    case Qd{a, b, c, d} Vn{l, h}:
      t0 t1 t2 t3 = mvm(a, l) mvm(b, h) mvm(c, l) mvm(d, h)
      vadd2(t0, t1, t2, t3)
```

Two things to take from this:

- **It confirms the DDSIM formula and the 4-way fork are idiomatic Bend.** The comment in the file is literally `# [[a,b],[c,d]] * (l,h) = (a*l + b*h, c*l + d*h)`. Note also `a b c e = f() g() h() i()` - **parallel lets are n-ary, not just binary** [R]; `mul` uses a single 8-way fork.
- **It is the argument for your indexed type.** Because `Mat`/`Vec` are unindexed, three of the four `mvm` cases and two of four `add`/`vadd` cases are unreachable, and the code returns `Vl{0}` / `Lf{0}` junk in them. In a language whose selling point is proof, silently returning zero in an impossible branch is exactly the kind of hole you do not want. `Q(n)` has no such branch. Structural correctness by typing is available here and the shipped benchmark does not take it.

Also note `mvm(m, +v)`: `v` must be a **reusable** binder because `l` and `h` are each consumed twice (`a*l` and `c*l`). Your `mix` formulation avoids that - it consumes `l` and `r` exactly once each and returns both new subtrees - so only the scalars get duplicated. That is the affine-clean version and it is also the FFT butterfly shape. Worth preferring.

`bench/runtime/tree-bitonic/main.bend` (145 lines) is the other template: `warp`/`flow`/`bsort` over tree levels, i.e. the butterfly pattern. [R]

### 1.7 What is actually provable here, and one hole in the prototype

This is where the language earns its keep, so be precise about which claims are free, which need a proof, and which are impossible.

**Free, by typing (no proof body at all):**

- `apply(n, rs, g, q: Q(n)) -> Q(n)` - **gate application preserves the state shape and the qubit count**. The signature *is* the theorem; there is no way to write a version that returns the wrong number of amplitudes. Compare the flat-array world, where this is a test you hope you wrote.
- Totality / termination: structural recursion on `n` is accepted by the checker with no fuel argument and no `@unsafe`. [V - the prototype checks.]
- No impossible branches to fill with junk (unlike `tree-matmul`, §1.6).

**Provable with real work, and float-free:**

- gate count, circuit depth, qubit-index bounds
- `apply` with an all-`Skip` roles list is the identity (induction on `n`)
- commutation of gates on disjoint qubit sets

**Not provable, ever, in Bend 2:** anything about the amplitudes themselves. `F32` is axiomatic - "F32 is axiomatic: nothing about floating point can be proven" [R - README]. So `X . X = id`, unitarity, and norm preservation are **out of reach with F32 amplitudes**, even though they are the properties you would most like to state.

**This is the real argument for exact arithmetic (§3): not accuracy, but provability.** With amplitudes in an exact ring built from `Nat`/`U32` integers, `X . X = id` and `H . H = id` become ordinary inductive proofs. With `F32` they are untouchable. If the goal is "a simulator whose correctness is checked", the amplitude type is the decision that determines whether there is anything to check.

**A hole in the current prototype, worth fixing.** Roles are a plain `List<&2, Role>`, and `apply`/`mix` have a `case 1n++p Nil{}:` arm. So a roles list **shorter than `n` silently drops the gate**, and one longer than `n` silently ignores the tail. That is the same class of defect as `tree-matmul`'s `Vl{0}` junk branches - a wrong input produces a plausible wrong answer instead of an error.

I tried to close it with a length-indexed roles type, mirroring `Q(n)`:

```python
def R(n: Nat) -> Type:
  match n:
    case 0n:    Unit
    case 1n++p: Role & R(p)
```

**It does not work, for a specific reason** [V]: `def mix(n: Nat, +rs: R(n), ...)` is rejected with `expected : Data / observed : Type`. Bend's built-in pair type `A & B` is `Type`-kinded, i.e. **linear**, and there is no kind parameter on `&` to make a pair-nest `Data`. But roles must be *duplicated* at every `Skip` fork (both halves need the same tail), so they must be `Data`. The original prototype's `List<&2, Role>` works precisely because `List` is declared `type List<a, -A: Kind(a)> is Kind(a)` and so can be instantiated at `&2` [R - `base.bend`].

Note this is *not* a problem for `Q(n)`: the state is linear and consumed exactly once, which is exactly what you want, and the prototype confirms it type-checks and runs [V].

**Recommended mitigation** (not verified - I stopped experimenting rather than guess at whether Bend 2 supports value-indexed inductive families [U]): keep `List<&2, Role>` for the roles, but never let a caller build one by hand. Provide smart constructors - `single(n, k, g)`, `controlled(n, c, t, g)`, `multi_controlled(n, cs, t, g)` - that are structurally recursive on `n` and therefore emit exactly `n` roles by construction. Then state `law roles_length: for n: Nat; {List.length(single(n,k,g)) == n : Nat}` and prove it once per constructor. That moves the guarantee from "hope the caller counted" to "proved once", without needing an indexed type.

Two Bend constraints this experiment surfaced, both of which will bite while writing the real thing [V]:

- **`match` scrutinees must come in binder order.** Binding `(r0, rest) = rs` and then destructuring `l` and `r` before `match r0:` is rejected: `match scrutinees in binder order (this variable is unbound, consumed, or out of order: reorder the match)`. Match on the role *first*, destructure the subtrees inside each arm.
- **`match` cannot scrutinise a computed value**, and a destructuring `let` counts as a match - which is why the prototype needs the `mix.join` / `mix.ctrl` helpers just to take apart a pair returned by a recursive call [R - visible in `q.bend`]. Expect one trivial helper per "I got a tuple back and need its parts" site.

### 1.8 Decision diagrams as the compressed relative - and why probably not for you

QMDD is the same tree with **hash-consed sharing plus edge weights**:

- Niemann, Wille, Miller et al., "QMDD: A Decision Diagram Structure for Reversible and Quantum Circuits" / "Quantum Multiple-Valued Decision Diagrams", https://link.springer.com/chapter/10.1007/978-3-319-63724-2_4
- Zulehner, Hillmich & Wille, "How to Efficiently Handle Complex Values? Implementing Decision Diagrams for Quantum Computing", https://arxiv.org/pdf/1911.12691 (downloaded)
- Implementation: MQT DDSIM, https://github.com/munich-quantum-toolkit/ddsim ; docs https://mqt.readthedocs.io/projects/core/en/latest/dd_package.html
- Q-Sylvan (parallel DD package), https://arxiv.org/pdf/2508.00514
- "Simulation Paths for Quantum Circuit Simulation with Decision Diagrams", https://arxiv.org/pdf/2203.00703
- Tensor-network-flavoured variant (TDD), https://arxiv.org/pdf/2009.02618

Normalisation, from the MQT docs [R]: pick "a maximum-magnitude edge (preferring the left edge within numerical tolerance) and make its normalized weight real and nonnegative. The incoming edge retains its complex phase."

**Why it is a bad fit for Bend 2 specifically.** The entire benefit comes from a *global* unique table (hash consing) plus *global* memoization caches for the sub-products and sub-sums - Zulehner & Wille say so explicitly: "redundancies can again be exploited by caching sub-products and sub-sums" [R]. That means shared mutable state across the whole traversal. Bend gives you single-owner arrays and affine values; a cross-thread shared table needs atomics and `@unsafe`, which is "experimental" per the README [R]. You would be fighting the language for the one feature it does not have, and you would lose the proof story. **Recommendation: build the dense tree, cite QMDD as the compression path you are deliberately not taking.**

---

## 2. Minimal "complete" simulators as size and feature references

Line counts below were produced by fetching the raw source and counting it, not by trusting the README. Several claims do not survive counting.

### 2.1 Disambiguating "qusim"

At least four unrelated things carry the name. The one people mean is **QuSim.py** by adamisntdead (727 stars), https://github.com/adamisntdead/QuSimPy . Distinct from `qsim.lisp` (the file inside Robert Smith's Common Lisp quantum interpreter, https://github.com/stylewarning/quantum-interpreter), from Google's production **qsim** (https://github.com/quantumlib/qsim, thousands of lines, not minimal), and from several transmon/NV-centre physics packages.

**QuSim.py's line count is quoted three different ways.** The HN title says 100 lines (https://news.ycombinator.com/item?id=17549471), its README says 150, and the actual file is **132 total / 93 code**. It also uses `np.complex` and `np.matrix`, both removed or deprecated in modern NumPy, so it probably no longer runs unmodified [U - not executed].

### 2.2 Verified line counts

| Project | Lang | Claimed | **Counted** | URL |
|---|---|---|---|---|
| Albarghouthi "27 lines" | Python | 27 | 27 logical statements, ~68 physical | https://barghouthi.github.io/2021/08/05/quantum/ |
| QuSim.py | Python | 100 / 150 | **132 total, 93 code** | https://github.com/adamisntdead/QuSimPy |
| qsim.lisp | Common Lisp | 150 / "124 SLOC" | **147 total, 126 code** (honest) | https://github.com/stylewarning/quantum-interpreter |
| Gidney's CHP port | Python | "simple reference" | **216** | https://github.com/Strilanc/python-chp-stabilizer-simulator |
| MicroQiskit | Python | none | **249 total, 161 code** | https://github.com/qiskit-community/MicroQiskit |
| MicroQiskit | Godot/GDScript | none | **176** | same repo, `versions/Godot` |
| MicroQiskit | Lua | none | **263** | same repo, `versions/Lua` |
| MicroQiskit | C++ | none | **497** | same repo, `versions/C++` |
| QCSim.py | Python | none | **779** | https://github.com/lvillasen/Quantum-Computer-Simulator |
| Aaronson's CHP | C | none | **859** | https://www.scottaaronson.com/chp/chp.c |
| min_qsim | Python | "minimalistic" | **896 across 6 files** | https://github.com/ghx312/min_qsim |
| qoord | Python | "~1000" | **~1250 lib** (`states.py` alone 727) | https://github.com/scottmckuen/qoord |
| muqcs.js | JS | "1000-2000 LOC" | **2579** (inline in `index.html`) | https://github.com/MJMcGuffin/muqcs.js |

`min_qsim` bills itself as "Minimalistic" at 896 lines, ~7x QuSim.py. `muqcs.js`'s paper claims 1000-2000 while shipping 2579 (it bundles a regression suite and the HTML shell, so not dishonest, just not 1-2k).

### 2.3 Feature matrix

Rows ordered by size. Y = present, N = absent, ~ = partial.

| | Albarghouthi (27) | QuSim.py (132) | qsim.lisp (147) | CHP-py (216) | MicroQiskit (249) | min_qsim (896) | muqcs.js (2579) |
|---|---|---|---|---|---|---|---|
| 2^n vector, init \|0..0> | Y | Y | Y | N (tableau) | Y | Y | Y |
| Arbitrary 1-qubit unitary | Y | N (named dict) | Y (any k-qubit matrix) | N (Clifford only) | ~ (rx/ry/rz Euler) | N | ~ [U] |
| Gate on **non-adjacent** qubit | **N (adjacent only)** | Y | Y | Y | Y | Y | Y |
| Controlled gates | ~ (CNOT matrix) | ~ (CNOT) | ~ (supply matrix) | ~ (CNOT) | Y (cx, crx) | Y (CNOT,CZ,CCX) | **Y (arbitrary ctrl/antictrl)** |
| Multi-controlled (>=2 ctrl) | N | N | ~ (manual) | N | N | ~ (CCX) | Y |
| Measurement **with collapse** | **N (author says so)** | **~ (latches a value, never projects)** | Y | Y | Y | Y (full + partial) | ~ [U] |
| Shot sampling -> counts | N | N | N | N | **Y** (`shots=1024`) | Y | N [U] |
| Pauli expectation values | N | N | N | N | N | N | ~ (many metrics, no <P> API) |
| OpenQASM 2/3 parsing | N | N | N | N | N | N | N |
| Density matrix / noise | N | N | N | N | ~ (readout error only) | N | Y |
| Gate fusion | N | N | N | n/a | N | N | N |
| **O(2^n) pairwise apply** | **N (full Kronecker, O(4^n))** | **N (full Kronecker)** | **N (full lifted matrix)** | O(q^2) | **Y** | Y | Y |

### 2.4 What each author treats as "complete"

- **MicroQiskit** (James Wootton / qiskit-community) is the best single reference point, because finding the floor *was* the design goal: "we have created MicroQiskit: the smallest and most feature-poor framework for quantum computing. It has all the basic features and only the basic features." His basic features = `{x,y,z,h,rx,ry,rz,cx,crx}` + `measure` + statevector/counts/memory/probabilities + readout-error noise, in one dependency-free file, ported to 7+ languages. https://github.com/qiskit-community/MicroQiskit
- **Robert Smith / qsim.lisp**: completeness = *generality of the gate*, not breadth of the gate set. Arbitrary unitaries of any dimension on arbitrary, arbitrarily-indexed qubits, plus measurement. About a third of his 147 lines is the permutation machinery (`permutation-to-transpositions`, `transpositions-to-adjacent-transpositions`) that lifts a gate onto non-adjacent qubits. https://www.stylewarning.com/posts/quantum-interpreter/
- **Albarghouthi**: completeness = *universality of the gate set* (`{H,S,T,CNOT}`), and measurement is explicitly out of scope: "Our simulator doesn't implement measurement, because it represents the entire probability distribution explicitly." https://barghouthi.github.io/2021/08/05/quantum/
- **McGuffin, Robert & Ikeda** (arXiv:2506.08142, June 2025) give the fullest published checklist: statevector and density matrix, arbitrary control/anticontrol, partial trace, per-qubit P(1)/phase/purity/Bloch, von Neumann entropy, concurrence. https://arxiv.org/abs/2506.08142
- **Roger Luo** (Yao.jl): the *performance* floor is four things - general unitary on specified locations, controlled gates, subspace iteration via bitmasks, matvec in subspaces - claimed in "less than 600 lines". https://rogerluo.dev/posts/yany/
- **Craig Gidney**: there is **no** "simulator in N lines" post on algassert.com [U - searched the site and his repos]. But he is the citation for *not* doing Kronecker products. From Quirk's performance history: tensoring a column's gates "into a single giant matrix, then smashing that matrix into the state vector" was the wrong design, because "The matrices defined by single-qubit gates are sparse: you can apply them with a single scan over the state vector, in linear time. The big-fucking-matrix approach, on the other hand, does quadratic amounts of work." https://algassert.com/post/1626 , https://algassert.com/2016/05/22/quirk.html
- **Scott Aaronson**: no tiny state-vector simulator in his notes. His artifact is **CHP**, the original stabilizer simulator, 859 lines of C: https://www.scottaaronson.com/chp/chp.c , paper https://www.scottaaronson.com/papers/chp6.pdf , lecture notes https://www.scottaaronson.com/qclec.pdf

### 2.5 A defensible "minimum complete" feature list

**Tier 1 - the floor, present in every project above that calls itself a simulator:**
1. `2^n` complex amplitudes, initialised to `|0..0>`
2. single-qubit gate at an arbitrary qubit index
3. one entangling two-qubit gate (CNOT)
4. a universal set: `H` + (`T` or `S` or `rz`) + `CNOT`

**Tier 2 - what separates "complete" from "toy". Each is where a specific project above gets caught out:**

5. **Measurement with real collapse** (project + renormalise). Albarghouthi skips it and says so; QuSim.py fakes it by latching a classical value and then refusing further gates. This is the sharpest dividing line in the corpus.
6. **Gates on arbitrary, non-adjacent qubits.** The adjacency restriction is the most common hidden cheat. *Your role-walk gets this for free, which is a genuine advantage worth stating.*
7. **Shot sampling -> counts.** What makes the thing comparable to hardware. MicroQiskit treats it as basic.
8. **Arbitrary single-qubit unitary**, as a matrix or via rx/ry/rz.
9. **O(2^n) pairwise application, not full Kronecker.** Three of the tiny sims build full `2^n x 2^n` matrices and are `O(4^n)` per gate. *Your tree recursion is `O(2^n)` by construction, which is the right side of this line.*

**Tier 3 - explicitly NOT minimum-complete** (absent from every project under ~800 lines): Pauli expectation values (0 of 7), OpenQASM parsing (0 of 7 - the only parsers anywhere are QCSim.py's bespoke IBM-QE dialect at 779 lines), density matrices/noise, gate fusion, multi-controlled gates.

**Empirical target: MicroQiskit's 249 lines / 161 code lines** covers Tiers 1+2 plus readout noise in one file. Your verified prototype is at 138 lines with Tier 1 + item 6 + multi-control (which MicroQiskit lacks) already done, and no measurement yet. **Tiers 1+2 in Bend 2 should land around 350-500 lines**, the multiplier over Python coming from Bend's mandatory annotations, hand-rolled complex arithmetic, hand-rolled PRNG, and `match`-instead-of-`if`.

---

## 3. Exact arithmetic for Clifford+T

**This is the section that most changes the project's ambition.** Exact amplitudes are not just more accurate - they are the only way anything about the amplitudes becomes *provable* in Bend 2, because `F32` is axiomatic (§1.7). And the effort is far lower than expected: **no multiplication is needed at all.**

### 3.0 Convention warning: the primary sources disagree on coefficient order

Mixing these will silently corrupt your code.

- **Ross-Selinger / Giles-Selinger**: `Z[omega] = {a*w^3 + b*w^2 + c*w + d}` - `(a,b,c,d)` is **descending** powers. https://arxiv.org/abs/1403.2975 , https://arxiv.org/abs/1212.0506 (Def. 2.1)
- **Kliuchnikov-Maslov-Mosca**: `Z[omega] = {a + b*w + c*w^2 + d*w^3}` - **ascending**. https://arxiv.org/abs/1206.5236

Use **Selinger (descending)**, because that is what the production Haskell implements, so you can diff against working code. From `newsynth`'s `Ring.hs`: `data Omega a = Omega !a !a !a !a` with the comment "The value `Omega a b c d` represents aw^3+bw^2+cw+d". https://hackage-content.haskell.org/package/newsynth-0.4.1.0/src/Quantum/Synthesis/Ring.hs

### 3.1 The rings (verbatim, Ross-Selinger arXiv:1403.2975)

> - `Z[sqrt2] = {a+b*sqrt2 | a,b in Z}`, the ring of quadratic integers with radicand 2
> - `Z[omega] = {a*w^3+b*w^2+c*w+d | a,b,c,d in Z}`, the ring of cyclotomic integers of degree 8
> - `D = Z[1/2] = {a/2^k}`, the dyadic fractions
> - `D[sqrt2] = Z[1/sqrt2] = {a+b*sqrt2 | a,b in D}`
> - `D[omega] = Z[1/sqrt2, i] = {a*w^3+b*w^2+c*w+d | a,b,c,d in D}`

with `w = e^(i*pi/4) = (1+i)/sqrt2`, `w^2 = i`, `w^4 = -1`.

**Answer to your question: an element is 4 integers plus one shared exponent**, `t = (a*w^3 + b*w^2 + c*w + d) / sqrt2^k`. Do *not* use 4 separate dyadics - push all the `1/2^j` into the shared `sqrt2^k` and keep the numerator in `Z[omega]`. (`newsynth` uses per-coefficient dyadics only because synthesis needs a `Fractional` instance.)

The key identity, confirmed both in KMM ("it is possible to write 1/sqrt2 as (w-w^3)/2") and in `Ring.hs` (`roottwo = Omega (-1) 0 1 0`, `roothalf = Omega (-half) 0 half 0`):

```
sqrt2  = w - w^3          -> (a,b,c,d) = (-1, 0, 1, 0)
1/sqrt2 = (w - w^3)/2     -> (-1/2, 0, 1/2, 0)
```

### 3.2 Multiplication: negacyclic convolution in Z[x]/(x^4+1)

For `t=(a,b,c,d)`, `s=(A,B,C,D)`:

```
a'' =  a*D + b*C + c*B + d*A
b'' = -a*A + b*D + c*C + d*B
c'' = -a*B - b*A + c*D + d*C
d'' = -a*C - b*B - c*A + d*D
```

16 multiplies, 12 add/sub. This matches `newsynth`'s `Num (Omega a)` instance term for term [R]:

```haskell
Omega a b c d * Omega a' b' c' d' = Omega a'' b'' c'' d'' where
  a'' = a*d' + b*c' + c*b' + d*a'
  b'' = b*d' + c*c' + d*b' - a*a'
  c'' = c*d' + d*c' - a*b' - b*a'
  d'' = d*d' - a*c' - b*b' - c*a'
```

**You will never call this** - see §3.6.

### 3.3 The operations you actually need

**Multiply by `omega` - this is your T gate, and it costs zero multiplications:**

```
w * (a,b,c,d) = (b, c, d, -a)
```

Rotate the tuple, negate the wrapped element. `T = diag(1,w)`, `S = diag(1,w^2)`, `Z = diag(1,w^4)`, `T-dagger = diag(1,w^7)`.

**Multiply / divide by `sqrt2`:**

```
sqrt2 * (a,b,c,d) = ( b-d,     a+c,     b+d,     c-a    )
(a,b,c,d) / sqrt2 = ((b-d)/2, (a+c)/2, (b+d)/2, (c-a)/2)
```

4 add/sub each; division is the same shape followed by halving, since `1/sqrt2 = sqrt2/2`.

**Addition** with equal `k` is componentwise (4 adds). With different `k1 < k2`, scale the smaller-exponent numerator up by applying the `sqrt2`-multiply `(k2-k1)` times. **But keep one shared `k` for the whole state vector and this case never arises** - every Clifford+T gate scales all amplitudes uniformly, so a shared `k` is a free invariant, and reduction becomes a single global pass. (It breaks for gates that scale only *some* amplitudes by `1/sqrt2`, e.g. controlled-H; decompose those into Clifford+T first.)

### 3.4 Reduction: the exact condition (your guess was right)

```
t/sqrt2 is in Z[omega]   <=>   (a - c) is even  AND  (b - d) is even
```

(equivalently `a+c` and `b+d` even - same thing, since `a-c` and `a+c` share parity.)

Confirmed three ways:

1. **Giles-Selinger residue calculus** (arXiv:1212.0506). With the residue map `rho: Z[omega] -> Z2[omega]` written as a bit string `pqrs`: *"Let t in Z[omega]. Then t/2 in Z[omega] if and only if rho(t) is twice reducible, and t/sqrt2 in Z[omega] if and only if rho(t) is reducible."* And: *"For a residue x, the following are equivalent: (a) x is reducible; (b) x in {0000, 0101, 1010, 1111}; (c) sqrt2*x = 0000; (d) x-dagger x = 0000."* Those four bit strings are exactly `p=r` and `q=s`.
2. **`newsynth`'s own `instance DenomExp DOmega`** [R]: `k' | k>0 && even (a'-c') && even (b'-d') = 2*k-1 | otherwise = 2*k`
3. Exhaustive check over all 16 parity classes plus 20k random elements, zero disagreements [V - verified in this session].

Implementation: two parity tests. Exactly 4 of 16 residue classes are reducible, so a random element reduces with probability 1/4 (measured 4934/20000 [V]).

Equivalent global criterion, Ross-Selinger Appendix C: *"in Z[omega], we have sqrt2^k | t if and only if 2^k | t-dagger t."*

### 3.5 Conjugates, norm, and sde

```
complex conjugate:  (a,b,c,d)-dagger = (-c, -b, -a, d)
sqrt2-conjugate:    (a,b,c,d)-bullet = (-a,  b, -c, d)
norm squared:       |t|^2 = (a^2+b^2+c^2+d^2) + (cd + bc + ab - da)*sqrt2
weight:             ||t||^2 = a^2+b^2+c^2+d^2
```

Both conjugate formulas match `newsynth`'s `adj`/`adj2` exactly [R]. **`|t|^2` is 2 integers** `(p,q)` meaning `p + q*sqrt2`, i.e. it lands in `Z[sqrt2]` - that is your "lemma about `|z|^2` in `Z[1/sqrt2]`". For a full element, `|t|^2 = (p + q*sqrt2)/2^k`.

**sde**, from KMM (arXiv:1206.5236): *"The smallest denominator exponent, sde(z,x), of base x in Z[omega] with respect to z in Z[1/sqrt2,i] is the smallest integer k such that z*x^k is in Z[omega]."* Their Lemma 2 bounds how one `H*T^k` step moves it: with `sde(|z|^2) >= 4`, `-1 <= sde(|(z+w*w^k)/sqrt2|^2) - sde(|z|^2) <= 1`, and Lemma 3 says each of `s in {-1,0,1}` is achieved for some `k in {0,1,2,3}`. Ross-Selinger's equivalent (Def. 3.4): *"If sqrt2^k t is in Z[omega], then k is a denominator exponent of t. The smallest such k>=0 is the least denominator exponent."* KMM also state the storage cost: *"to store U we need O(sde(U)) bits and therefore the addition on each step of the algorithm requires O(sde(U)) bit operations."*

### 3.6 The single most important finding: you need no multiplication

For the gate set `{X, Y, Z, H, S, S-dagger, T, T-dagger, CNOT, CZ, CCZ, SWAP}`, exact gate application needs only:

- **integer add / subtract** (the H butterfly, and `sqrt2`-reduction)
- **negate** (Z, CZ, the `omega`-rotation wraparound)
- **exact halve** (reduction)
- **parity test** (the reduction predicate)
- **index permutation** (X, CNOT, SWAP - zero arithmetic)

`T`, `S`, `Z` are multiplication by `w^j` = a tuple rotation plus one sign flip. **The 16-multiply general product is dead code.** For Bend that is a large win: it removes the entire class of multiply-overflow reasoning from your proof obligations.

Per-gate cost on `n` qubits: `H` = `2^(n+2)` add/sub + `2^(n+1)` parity tests; `T/S/Z` = `2^(n-1)` rotate+negate; `X/CNOT/SWAP` = 0 arithmetic; `CZ` = `2^(n-2)` negations.

### 3.7 Coefficient growth, and two provable bounds

**Bound 1: `k <= (number of H gates)`.** Nothing else in the Clifford+T set touches `k`. Provable by induction, trivially.

**Bound 2, the useful one - a consequence of unitarity, hence provable:**

```
sum over all basis states, sum over all 4 coefficients of e^2  =  2^k   (exactly)
  =>  every coefficient satisfies  |e| <= sqrt2^k = 2^(k/2)
```

Derived from Giles-Selinger's lemma *"Consider a vector u in D[omega]^n. If ||u||^2 is an integer, then weight^2(u) = ||u||^2"* plus `||sqrt2 * t||^2 = 2||t||^2`. Verified to hold **exactly** (not approximately) across 600 consecutive random gates [V].

**Measured growth** [V - a reference simulator written and run in this session, n=2..10, random Clifford+T]:

| T-fraction | gates | #H | #T | final k | max coeff bits |
|---|---|---|---|---|---|
| 0.00 | 800 | 482 | 0 | **6** | 1 |
| 0.05 | 3000 | 1717 | 165 | 68 | 32 |
| 0.10 | 3000 | 1612 | 330 | 98 | 47 |
| 0.20 | 2000 | 945 | 407 | 94 | 45 |
| 0.50 | 1000 | 282 | 504 | 52 | 24 |

Reduction succeeds on ~85-95% of H gates, so `k` grows at ~0.02-0.25 per H depending on the mix. **Clifford-only circuits never grow at all** - `k` stayed at 6 after 482 H gates.

**The only published growth theorem is six months old:** Quist, Coopmans & Laarman, "Exact quantum decision diagrams with scaling guarantees for Clifford+T circuits and beyond", https://arxiv.org/abs/2602.17775 (Feb 2026), Theorem 4.5: *"The complex numbers encountered when simulating U gate-by-gate on |0>^(x)n are elements of R_{O(n+t)} and can thus each be described in O(n+t) bits"* (`t` = T-count), with node count `2^t * poly(g,n)`. They say of the `D[omega]` literature that *"all these works are again empirical, lacking any scaling guarantees."*

### 3.8 Overflow in 48-bit Nat: tenable, with one sharp trap

Since `|e| <= 2^(k/2)`, everything reduces to bounding `k`. Intermediate values need only one bit of headroom (the H butterfly's `a +- b` *is* the result).

| limit | condition | **provable** guarantee | measured |
|---|---|---|---|
| amplitude coefficient in 48-bit Nat | `k <= 93` | any circuit with **<= 93 H gates**, any n, any T-count | overflow at ~1500-1750 gates |
| same, 64-bit | `k <= 127` | <= 127 H gates | ~2200-2400 gates |
| **exact `|amp|^2` in 48-bit Nat** | **`k <= 46`** | <= 46 H gates | **~800 gates** |

**The trap: exact norm-squared overflows at roughly half the amplitude budget.** `p = a^2+b^2+c^2+d^2 <= 4*2^k = 2^(k+2)`, so exact probabilities need `k <= 46`, not 93. Three ways out: (i) compute probabilities in F32 from the coefficients - gate application stays exact, which is the point; (ii) a double-width `(hi,lo)` Nat pair for `p,q` only; (iii) reduce `k` opportunistically before measuring. **Decide this early**; it changes the amplitude type.

Rule of thumb: coefficient bits ~ `k/2`, and `k ~ 90-98` lands around **450-500 T gates**. So 48-bit Nat buys ~500 T gates for exact amplitudes, ~230 for exact probabilities. Clifford-only is unbounded.

**F32 readout** (the only place floats enter): `Re = d + (c-a)/sqrt2`, `Im = b + (c+a)/sqrt2`, then scale by `2^(-k/2)`. Lossy at ~1e-7 relative once `|e| > 2^24`, which is unavoidable and fine.

### 3.9 Sign without signed integers - three options

Bend has no signed integers, so this is a real design decision with no dominant answer.

| | representation | add cost | range | proof friendliness |
|---|---|---|---|---|
| **A** sign-magnitude | `(s: U32, m: Nat)`, canonical `m=0 => s=0` | 1 compare + 1 add/sub + sign logic | `k <= 93` | 4-case analysis in `add` |
| **B** biased | store `e + B` | `x + y - B`, branch-free | `k <= 91` | easy, but must prove the bias never wraps |
| **C** difference pair | `(pos, neg): Nat x Nat`, value `pos - neg` | **2 Nat adds, branch-free** | `k <= 95` | **best** - `add` is componentwise Nat `+`, so commutativity and associativity are *free*; `neg` is a swap |

**Option C is the one to pick for a proof-first language.** Its cost is 2x memory (8 Nats per amplitude) and a periodic `min`-subtraction normalisation pass. The payoff is that the ring axioms you most want to prove reduce to `Nat.add_comm`, which is the one arithmetic law Bend's base library already ships [R - see `bend-notes.md`].

### 3.10 Implementation effort: measured at 128 lines

A complete `Nat`-only exact `D[omega]` simulator in your constraint style (sign-magnitude, no negative literals, no mutation) was written and tested during this research [V]:

| layer | lines |
|---|---|
| signed-int-over-Nat (`s_add`, `s_sub`, `s_neg`, `s_mul`, `s_half`, `s_is_even`) | 22 |
| `Z[omega]` ring (add, sub, neg, mul_w, mul_w^j, conj, bullet, mul_rt2, divisible_rt2, div_rt2, mul, normsq) | 46 |
| `Z[sqrt2]` sign / comparison (for measurement ordering) | 14 |
| F32 readout | 10 |
| state vector + all gates + global reduce | 36 |
| **total** | **128** |

Validated on 40 random 4-qubit 60-gate Clifford+T circuits; worst deviation from a dense float reference was `2.2e-15`, which is the *float reference's* error, not the exact simulator's.

So the exact-arithmetic layer is roughly **the same size as the tree/gate layer**. Proofs on top are the real cost - a 3-10x line ratio is a guess with no data for Bend. [U]

### 3.11 Prior art in exact simulation

**A full exact `D[omega]` state-vector simulator already exists: SliQSim.** Tsai, Jiang & Jhang, "Bit-Slicing the Hilbert Space", https://arxiv.org/abs/2007.09304 (DAC 2021), code https://github.com/NTU-ALComLab/SliQSim . It uses **exactly this representation** - *"we only need to maintain five integers to represent a complex number"* - bit-sliced into `4*r` ROBDDs over CUDD, with `r` (default 32) **widened reactively at runtime** when a carry escapes the top slice. There is no a-priori bound in the paper. The TACAS 2025 follow-up calls it *"the first exact quantum circuit simulator."* https://link.springer.com/chapter/10.1007/978-3-031-90660-2_7

**So a fixed-48-bit design with a *proved* `k <= #H` precondition would be a genuinely new point in the design space** - everyone else either widens reactively (SliQSim) or rounds (quizx).

Other prior art:

- **newsynth / gridsynth** (Selinger, Haskell) - the reference exact `D[omega]` linear algebra, arbitrary precision, dimension-indexed matrices so *"there are no run-time dimension errors."* A synthesis library, not a simulator, but the layer to diff against. https://www.mathstat.dal.ca/~selinger/newsynth/ , https://hackage.haskell.org/package/newsynth . **Two corrections to the brief:** there is no `quantum-synthesis` package on Hackage, and **Quipper reuses newsynth's rings** rather than defining its own (https://hackage.haskell.org/package/quipper-libraries-0.9.0.0/docs/Quipper-Libraries-Synthesis.html documents *"a 2x2 unitary operator with entries from the ring D[w] = Z[1/sqrt2,i]"*).
- **Feynman** (Matthew Amy) - the repo is https://github.com/meamy/feynman (`msr-quarc/Feynman` 404s). Exact, computes `<y|U|x>` one amplitude at a time as a path sum with an explicit `sde` field; `hgate` bumps `sde`, `tgate` carries phase `1/4`. Phase ring is dyadic rationals mod 2, **not** `Z8`. https://arxiv.org/abs/1805.06908
- **quizx** (Rust) - **the instructive counter-example.** `scalar.rs` has a genuine `D[omega]` ("four Dyadic rationals ... a + b*w + c*w^2 + d*w^3") with the correct `w^4=-1` convolution, but `dyadic.rs` uses `type Mantissa = u64` and its `Add` **rounds on overflow** (`self.val = self.val.wrapping_shr(1); self.exp += 1;`). Right ring, fixed mantissa, silently loses exactness. Do not repeat this.
- **Bravyi-Gosset stabilizer rank** (https://arxiv.org/abs/1601.07601 , https://arxiv.org/abs/1808.00128) is Monte-Carlo - it *approximates* a norm to relative error `eps` in time `chi*n^3*eps^-2`, so the output is randomised regardless of the inner arithmetic. Not what you want. Their CH-form tableau is exact in `F,G,M,gamma,v,s` but Cirq's implementation keeps the global phase `omega` as a Python `complex` [R - `stabilizer_state_ch_form.py`].
- **Do not be misled by titles:** "Clifft: Fast Exact Simulation of Near-Clifford Quantum Circuits" (https://arxiv.org/abs/2604.27058) is float - "exact" there means non-sampling.
- **AutoQ** is exact by design: *"Our technique computes with an algebraic representation of quantum states, avoiding the inaccuracy of working with floating-point numbers."* (See §1.3b - and note its `Z^5` leaf alphabet is this same ring.)
- Float-based, for contrast: MQT DDSIM (`fp` = `double`), pyqrack, Stim and `cirq.CliffordTableau` (exact tableaux, no amplitudes), Qiskit `StabilizerState` (exact tableau, float probabilities).

### 3.12 Cheaper exact schemes - and they are *much* cheaper

**(a) Aaronson-Gottesman tableau (CHP)** - https://arxiv.org/abs/quant-ph/0406196 , PRA 70, 052328. Code at https://www.scottaaronson.com/chp/

Stored: bits `x_ij, z_ij` for `i in 1..2n, j in 1..n` plus sign bits `r_i`, as a `2n x (2n+1)` matrix - *"So the number of bits needed is 2n(2n+1) ~ 4n^2"* - plus one scratch row. Rows `1..n` are destabilizers, `n+1..2n` stabilizers. `x_ij z_ij` encodes the j-th Pauli: *"00 means I, 01 means X, 11 means Y, and 10 means Z"*. Initial `|0>^(x)n`: all `r_i = 0`, `x_ij = delta_ij`, `z_ij = delta_(i-n)j`.

Gate updates, **verbatim, and they are pure bit operations**:

> **CNOT from control a to target b.** For all `i in {1..2n}`, set `r_i := r_i XOR x_ia*z_ib*(x_ib XOR z_ia XOR 1)`, `x_ib := x_ib XOR x_ia`, and `z_ia := z_ia XOR z_ib`.
>
> **Hadamard on qubit a.** For all `i`, set `r_i := r_i XOR x_ia*z_ia` and swap `x_ia` with `z_ia`.
>
> **Phase on qubit a.** For all `i`, set `r_i := r_i XOR x_ia*z_ia` and then `z_ia := z_ia XOR x_ia`.

`rowsum(h,i)` is **the only place arithmetic appears**: `g` returns the power of `i` when two Paulis multiply (`0` if `x1=z1=0`; `z2-x2` if `x1=z1=1`; `z2(2x2-1)` if `x1=1,z1=0`; `x2(1-2z2)` if `x1=0,z1=1`), then `r_h := 0` if `2r_h + 2r_i + sum_j g(...) == 0 (mod 4)` and `1` if `== 2 (mod 4)` - *"it will never be congruent to 1 or 3"*.

Measurement of qubit `a`: check for `p in {n+1..2n}` with `x_pa = 1`. **Case I** (exists; outcome **random**): `rowsum(i,p)` for all `i != p` with `x_ia=1`; copy row `p` to row `p-n`; zero row `p` except `r_p` random and `z_pa = 1`; return `r_p`. **Case II** (none; outcome **determinate**): zero row `2n+1`; `rowsum(2n+1, i+n)` for all `i` with `x_ia=1`; return `r_{2n+1}`.

**So: gates are pure XOR/AND on bits; the entire arithmetic content is one 2-bit mod-4 counter.** `O(n)` per gate, `O(n^2)` per measurement, `4n^2` bits total instead of `2^n * 4` integers. **But it gives no amplitudes** - only measurement statistics. Different product, worth mentioning, not a substitute.

**(b) Restricted gate sets collapse the alphabet dramatically** - exhaustively enumerated for n=1,2,3 with no floats [V]:

**Real Clifford `{X, Z, H, CNOT, CZ, SWAP}` -> ONE integer, in `{-1,0,+1}`.**

| n | orbit size | max k | numerator alphabet |
|---|---|---|---|
| 1 | 8 | 1 | `{-1,0,1}` |
| 2 | 48 | 2 | `{-1,0,1}` |
| 3 | 480 | 3 | `{-1,0,1}` |

Amplitude = `m / sqrt2^k` with `m in {-1,0,1}`, `k <= n`. **Two bits per amplitude and zero arithmetic.** Closure is trivial to prove: H gives `m_i +- m_j` with `k+1` (values in `{-2..2}`), then the global halving restores the alphabet. **This is tighter than the "2 integers + exponent" you proposed** - `Z[1/sqrt2]` in general needs `(P,Q,e)` for `(P+Q*sqrt2)/sqrt2^e`, but for a state vector reachable by real Clifford the single integer suffices.

**Full Clifford `{H,S,Z,X,CNOT,CZ,SWAP}` -> TWO integers (Gaussian), coefficients in `{-1,0,1}`.** Orbit sizes 48 / 480 / 8640 for n=1,2,3 = 8x the standard stabilizer-state counts (6/60/1080), confirming exactly 8 global phases. `D[omega] = Z[i][1/sqrt2]` because `sqrt2 * Z[omega]` is contained in `Z[i]`, so **2 integers are complete for all of `D[omega]`**, halving storage. Catch: in Gaussian form you can only reduce `k` by 2, so your `k` may exceed the least denominator exponent by 1 - harmless.

**Adding T forces you back to 4 integers.** `T` multiplies by `w = (1+i)/sqrt2`, and `sqrt2 * Gaussian` is not in `Z[i]`, so no shared-`k` Gaussian form exists. A "phase-only" form `w^e * m / sqrt2^k` is **not closed under addition** (`w^0 + w^1` is not a monomial), so that shortcut does not exist. The honest minimum for Clifford+T is `(g0 + g1*w)` with `g0,g1` Gaussian, i.e. 4 integers.

**(c) The eighth-root-of-unity phase-only form for stabilizer states** - this is exactly what you were reaching for, and it is published. de Beaudrap & Herbert, "Fast Stabiliser Simulation with Quadratic Form Expansions", https://arxiv.org/abs/2109.08629 , Quantum 6, 803 (2022):

```
              tau^g
  |psi>  =  ---------  sum over x in {0,1}^r   i^(x^T Q x)  |A x XOR b>
            sqrt(2^r)
```

> "for integer matrices A and Q where furthermore Q is symmetric, and where `Ax XOR b` denotes the reduction modulo 2 of the integer vector `Ax + b`"

with **`tau = sqrt(i) = exp(i*pi/4)`**, `A` an `n x r` binary matrix, `b` an `n`-vector, `0 <= r <= n`. They constrain the global phase to a power of `tau`, and note *"the expression in the exponent of i may be evaluated modulo 4."*

Stored: `A` (<= `n^2` bits), `b` (`n` bits), symmetric `Q` over `Z4` (~`r(r+1)` bits), `g` over `Z8` (3 bits), `r`. **Total ~`2n^2` bits, with arithmetic only in `Z2`, `Z4`, `Z8` - no integers of any width.** `O(nr)` per operation, contained in `O(n^2)`.

The exhaustive enumeration above independently confirms the structure [V]: for n=1,2,3 every stabilizer state had uniform amplitude magnitude, all amplitude ratios in `{1,-1,i,-i}`, and a global phase always one of 8 values. It does **not** extend to Clifford+T (T breaks uniform magnitude). Foundational predecessor: Dehaene & De Moor, PRA 68, 042318 (2003), https://arxiv.org/abs/quant-ph/0304125

---

## 4. Sampling measurement outcomes from a tree of probabilities

### 4.1 The probability recursion (primary source)

Zulehner & Wille give it directly [R] (arXiv:1707.00865):

> "P(q0 -> |0>) = sum over x in 0{0,1}^(n-1) |alpha_x|^2 ... sum |alpha_x|^2 = sum over x in 00{0,1}^(n-2) |alpha_x|^2 + sum over x in 01{0,1}^(n-2) |alpha_x|^2. This means we have to recursively determine the summed probabilities p_left and p_right of the sub-vectors."

With edge weights (their Fig. 6): `p = p_left * w_l^2 + p_right * w_r^2`. In a dense tree with no weights it is simply

```
prob(leaf a)      = re(a)^2 + im(a)^2
prob(Node(l, r))  = prob(l) + prob(r)          # one balanced fork
```

which is a single `O(2^n)` fold, parallel by construction. Collapse, verbatim: "we perform this collapse by changing the right (left) outgoing edge of the root node to point to the terminal and attach weight zero ... all amplitudes are divided by sqrt(P(q0 -> |0>))". Measuring every qubit is "repeat the procedure discussed above sequentially for all qubits q0, q1, ... qn-1" [R].

For a dense tree: measuring qubit k = walk down to level k, sum the two subtree probabilities, pick a branch, replace the other with zeros, scale the survivor by `1/sqrt(p)`. `O(2^n)` per measured qubit, `O(n * 2^n)` to measure all - acceptable, and it is what DDSIM does.

### 4.2 Single-shot: O(n) tree walk with subtree sums

If you precompute one **probability tree** (the `prob` fold above, kept as a tree of partial sums rather than collapsed to a scalar - `O(2^n)` space, `O(2^n)` time), then each shot is an `O(n)` root-to-leaf descent: at a node with left mass `pL` and total `p`, draw `u ~ U[0,1)`; if `u < pL/p` go left with `u' = u`, else go right with `u' = u - pL`. No random access, no cumulative-sum array, no binary search. This is the inverse-CDF method arranged as a tree descent, and it is the natural shape for Bend.

Cost for S shots: `O(2^n + S*n)`.

### 4.3 Batch sampling: split the uniforms at each node (this is the good one)

Two equivalent formulations, both known:

**(a) Recursive binomial splitting.** Hübschle-Schneider & Sanders, "Parallel Weighted Random Sampling", https://arxiv.org/pdf/1903.00227, §2.4 "Divide-and-Conquer Sampling", verbatim [R]:

> "Uniform sampling with and without replacement can be done using a divide-and-conquer algorithm [61]. To sample k out of n items uniformly and with replacement, split the set into two subsets with n' (left) and n - n' (right) items, respectively. Then the number of items k' to be sampled from the left has a binomial distribution (k trials with success probability n'/n). We can generate k' accordingly and then recursively sample k' items from the left and k - k' items from the right. This can be used for a communication-free parallel sampling algorithm."

and the parallelisation trick, which matters for Bend: "Different PEs have to draw the same random variates for the same interior node of the tree. This can be achieved by **seeding a pseudo-random number generator with an ID of this node**." That is a counter-based RNG keyed by tree position - see §4.5.

Cited as [61] = Sanders, Lamm, Hübschle-Schneider, Schrade & Dachsbacher, "Efficient random sampling - parallel, vectorized, cache-efficient, and online", ACM TOMS 44(3):29:1-29:14, 2018 [R]. So it is a classical technique with a proper citation, not folklore.

For weighted (your case) the success probability is `pL/p` instead of `n'/n`. Cost: `O(number of visited nodes)`, which is `O(min(2^n, S*n))` - you never descend into a subtree that got zero shots. **This is strictly better than S independent walks** and it prunes automatically on sparse states.

Cost: you need a `Binomial(k, p)` sampler, which is real work in a language with no RNG and no `lgamma`.

**(b) Split a list of uniforms - the version you proposed, and it avoids the binomial sampler.** Generate `S` uniforms, then at each node partition them by `pL/p`: those below go left (rescaled), those above go right (rescaled by subtracting `pL`). Same asymptotics, same pruning, and **it needs only `U[0,1)`**. If you keep the uniforms *sorted*, the partition at each node is a single split point rather than a filter, and the recursion is a clean `O(S + nodes)`; sorting `S` F32s in Bend is a bitonic sort over a tree, for which `bench/runtime/tree-bitonic` is a working template [R].

I could not find a paper presenting (b) in the quantum-shots setting specifically [U]; it is the standard "sorted uniforms / inverse transform" idea (see e.g. https://fairyonice.github.io/Inverse-transform-sampling-and-other-sampling-techniques.html [S]) applied to a probability tree. It is equivalent to (a) in distribution: partitioning `S` iid uniforms by a threshold `pL/p` yields a `Binomial(S, pL/p)` count on the left, by definition.

**Recommendation: (b).** No binomial sampler, no rejection sampling, no `lgamma`, and it is affine-friendly (each uniform is consumed once, lists split rather than duplicate).

### 4.4 Alias method: correct, but wrong shape for Bend

- Walker, "An efficient method for generating discrete random variables with general distributions", ACM TOMS 3(3):253-256, 1977
- Vose, "A linear algorithm for generating random numbers with a given distribution", IEEE TSE 17(9):972-975, 1991

Both cited in https://arxiv.org/pdf/1903.00227 (refs [71] and [70]) [R], which describes the structure: "An alias table consists of m := n buckets of capacity W/n each, where bucket b[i] represents some part w'_i of the weight of item i ... To sample an item from an alias table, pick a bucket index r uniformly at random, toss a biased coin that comes up heads with probability w'_r * n/W, and return item r for heads, or its alias a_r for tails." `O(n)` preprocessing, `O(1)` per sample.

For you: the table has `2^n` entries, construction is an inherently sequential light/heavy bucket-shuffling loop, and sampling needs random access. Bend's `Array<T>` is single-owner so it is *possible*, but the construction does not fork/join and you gain nothing over (b) since you are already paying `O(2^n)` to build the probability tree. Also relevant: Qiskit's own maintainers have this open question without a resolution - https://github.com/Qiskit/qiskit/issues/8618 ("What is the best method for sampling shots?"), which compares per-shot categorical (`O(S log k + k)`) against one multinomial draw (`O(k)`), notes "the crossover always occurs for n/k well below 1", mentions the alias method, and closes with no decision [R]. Do not over-engineer this; nobody else has.

### 4.5 A tiny PRNG on 32-bit words - verified working in Bend 2

**Bend has no random number source.** The effect list is print, print_err, get_env, now, sleep, spawn, channels, files, TCP, UDP, window, audio [R - README]. So: seed from `IO.now()` (or an env var, for reproducibility) and thread a pure PRNG. Bend's own benchmarks do exactly this - `tree-matmul` hand-rolls LCGs with constants 1664525, 214013, 48271, 2654435761 [R].

**Design steer: use a counter-based (stateless) generator, not a stateful one.** A stateful PRNG has to be threaded through the traversal, which serialises a fork/join tree and fights affinity. A counter-based generator computes the i-th value as `hash(seed, i)` with no state, so every fork is independent - which is precisely the trick Hübschle-Schneider & Sanders use ("seeding a pseudo-random number generator with an ID of this node") [R]. The canonical reference is Salmon, Moraes, Dror & Shaw, "Parallel random numbers: as easy as 1, 2, 3", SC'11, https://www.thesalmons.org/john/random123/papers/random123sc11.pdf (downloaded).

**Important constraint: PCG32 is not practical here.** PCG32 needs a 64-bit LCG state and a 64-bit multiply. Bend has `U32` (32-bit) and `Nat` (48-bit unsigned, program aborts past 2^48-1) and no `U64` [R - README limitation list]. Emulating a 64-bit multiply from 32-bit halves is doable but it is ~10 lines of carry handling for no benefit at this scale. O'Neill's PCG paper, for the record: https://www.pcg-random.org/pdf/hmc-cs-2014-0905.pdf

#### xorshift32 (Marsaglia)

George Marsaglia, "Xorshift RNGs", Journal of Statistical Software 8(14), 2003 - https://www.jstatsoft.org/index.php/jss/article/view/v008i14 (I fetched the PDF and read it) [R].

The construction, verbatim: "If L is the n x n binary matrix that effects a left shift of one position on a binary vector y ... then, with T = I + L^a, the xorshift operation in C, `y^(y<<a)` produces the linear transformation yT". And: "there are many choices for a, b, c for which the matrices **T = (I + L_a)(I + R_b)(I + L_c)** have order 2^n - 1, when n = 32 or n = 64."

**Flag a typo in the paper.** The caption over the 32-bit table reads "the 32 x 32 binary matrix T = (I + L_a)(I + R_b)(**I + R_c**)", i.e. two right shifts. That contradicts the prose one sentence earlier and it is wrong. **I verified this computationally** [V]: I built the GF(2) matrices and computed the order of `T` by checking `T^(2^32-1) = I` and `T^((2^32-1)/p) != I` for every prime factor `p` of `2^32-1 = 3 * 5 * 17 * 257 * 65537`:

| triple | `(I+L_a)(I+R_b)(I+L_c)` | `(I+L_a)(I+R_b)(I+R_c)` |
|---|---|---|
| (13,17,5) | full period 2^32-1 | not full period |
| (5,17,13) | full period 2^32-1 | not full period |
| (1,3,10) | full period 2^32-1 | not full period |
| (2,5,15) | full period 2^32-1 | not full period |

So the L-R-L form is the correct one. `(5,17,13)` is in Marsaglia's `a < c` table; the paper then says "Of those 81 triples with a < c, the triple (c, b, a) also provides a full period T", which is what licenses the familiar **(13,17,5)**.

Update formula, and this is what to write:

```
y ^= y << 13
y ^= y >> 17
y ^= y << 5
```

Period `2^32 - 1`, state must never be 0 (0 is a fixed point). Verified as a permutation over 200k iterations from Marsaglia's seed 2463534242 with no repeats and no zero [V].

Known weaknesses, for honesty: plain xorshift32 fails some statistical tests; Panneton & L'Ecuyer and then Vigna analysed this and proposed scrambling (`xorshift*`, `xorshift+`). See Vigna, "An experimental exploration of Marsaglia's xorshift generators, scrambled", https://arxiv.org/pdf/1402.6246 and https://vigna.di.unimi.it/ftp/papers/xorshift.pdf , and Brent, "Note on Marsaglia's Xorshift Random Number Generators" / "Some long-period random number generators using shifts and xors", https://arxiv.org/pdf/1004.3115 . For sampling shot outcomes in a teaching/reference simulator, xorshift32 is fine; if you want better, use the finalizer below instead.

#### A 32-bit hash finalizer (better, and stateless)

From Chris Wellons' hash-prospector, which *measures* bias by exhaustive/statistical search - https://github.com/skeeto/hash-prospector [R]:

`lowbias32`, bias **0.17353355999581582**:

```c
uint32_t lowbias32(uint32_t x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    x ^= x >> 16;
    return x;
}
```

and a lower-bias variant found "through combinatorial optimization", parameters `[16 21f0aaad 15 d35a2d97 15]`, bias **0.10760229515479501**. That second one is the function usually copied around as "splitmix32"'s finalizer. Note the multiplier is `0xd35a2d97`, not the `0x735a2d97` that circulates in some copies.

Counter-based use: `u_i = mix32(seed + i * 2654435761)`. **Do not use `mix32(i)` with `i` starting at 0** - `mix32(0) = 0` [V], because the function is a pure xor-multiply network with no additive constant.

#### U32 -> uniform F32 in [0,1)

Take the **top 24 bits** and scale by `2^-24`:

```
u = to_f32(x >> 8) * 5.9604645e-8        # 5.9604645e-8 == 2^-24 exactly
```

Both steps are exact: `x >> 8` is in `[0, 2^24)` so the integer-to-F32 conversion is exact (F32 has a 24-bit significand), and multiplying by a power of two is exact. Result is in `{0, 2^-24, ..., 1 - 2^-24}`, uniform, and **never 1.0**.

Do **not** write `to_f32(x) * 2^-32`: converting a full 32-bit integer to F32 rounds, and values near `2^32` round up to exactly `2^32`, producing `u = 1.0`, which breaks any `u < p` dispatch.

#### All of it, verified running in Bend 2

`<scratchpad>/smoke/rng.bend` [V]. Bend output matched an independent Python/NumPy reference **exactly**:

| quantity | Bend 2 | Python reference |
|---|---|---|
| xorshift32 chain from seed 2463534242 | `723471715 2497366906 2064144800` | `723471715 2497366906 2064144800` |
| `mix32(0)`, `mix32(1)` | `0`, `114555507` | `0`, `114555507` |
| `4294967295 * 3 : U32` (wrap check) | `4294967293` | `4294967293` |
| `unif(0)`, `unif(0xFFFFFFFF)` | `0`, `0.99999994` | `0`, `0.99999994` (= 1 - 2^-24) |

So `U32.mul` wraps mod 2^32, `.^.`/`<<`/`>>` behave, and `U32.to_f32` is exact. [V]

**Two Bend gotchas this exposed, both costly if you hit them cold** [V]:

1. **No hex literals.** `0x21f0aaad` fails to parse: `expected : a numeric literal (NUMBER is U32, NUMBER n is Nat) / observed : 'x'`. Write constants in decimal (`0x21f0aaad` = `569420461`, `0xd35a2d97` = `3545902487`, `0xFFFFFFFF` = `4294967295`).
2. **Every binding used twice needs `+`, even for `U32`.** `b = x ^ y` then using `b` twice gives `expected : b / observed : b (consumed more than once)`. `U32` being `Data` makes it *copiable*, but a plain `let` is still *affine*. Write `+b = ...`. Same for parameters: `def xs32(+x: U32)`. Xorshift needs `+` on all three intermediates.

---

## 5. F32 sin / cos / sqrt - you do not need to implement these

**Bend 2's base library ships them as native primitives.** Verified two ways [V][R].

In `bend2/base.bend`, declared as `law`s (axioms with native implementations, no proof body):

```
law F32.sqrt:  for a: F32   F32
law F32.sin:   for a: F32   F32
law F32.cos:   for a: F32   F32
law F32.exp:   for a: F32   F32
law F32.pow:   for a: F32   for b: F32   F32
law F32.atan2: for a: F32   for b: F32   F32
```

Full list present: `add sub mul div mod pow atan2 neg abs sqrt exp log log2 log10 sin cos tan asin acos atan sinh cosh tanh floor ceil trunc is_eq is_ne is_lt is_le is_gt is_ge show bits read to_u32`, plus derived defs `min max clamp lerp square hypot round pi from_nat to_nat`.

The lowering, from `bend2/comp.ts` [R]:

```js
...tpl_ops("f32_", "sqrt exp log log2 log10 sin cos tan asin acos atan"
  + " sinh cosh tanh floor ceil trunc abs:fabs:abs",
  "f32_rewrap((f32)$o(f32_unbox($0)))", "Math.fround(Math.$o($0))"),
...tpl_ops("f32_", "pow atan2",
  "f32_rewrap((f32)$o(f32_unbox($0), f32_unbox($1)))",
  "Math.fround(Math.$o($0, $1))"),
```

So the C backend calls libm's **double** `sqrt`/`sin`/... and rounds the result to `f32`; the JS backend calls `Math.fround(Math.sqrt(x))`. On Metal there is a shim block:

```c
const SHIMS = "sqrt exp log log2 log10 sin cos tan pow fmod".split(" ")
  .map((n) => "#define " + n.padEnd(5) + " precise::" + n).join("\n")
  + "\n#define atan2 atan2_c99";
```

i.e. Metal gets `precise::sqrt`, `precise::sin`, etc., plus a hand-written `atan2_c99` because (their comment) "Metal's atan2 is NaN at the origin; libm answers +-0 or +-pi there".

Verified at runtime [V]: `F32.sqrt(2.0)` = `1.4142135`, `F32.div(1.0, F32.sqrt(2.0))` = `0.70710677`, `F32.sin(F32.pi()/4)` = `0.70710677` - all matching NumPy float32 exactly.

### What you should still worry about

- **Cross-backend determinism.** `sqrt` is safe: IEEE-754 requires correctly-rounded `sqrt`, and computing it in double then rounding to float is also correctly rounded (`2*24+2 = 50 <= 53`, so no double-rounding error). **`sin`, `cos`, `exp`, `log`, `pow` are not guaranteed identical** between libm-in-double (C), `precise::` (Metal) and `Math.fround(Math.sin(...))` (JS). They can differ by an ULP. If you want bit-identical results across backends - which you might, for a test suite with golden values - compute gate angles **once** and either (a) hard-code the resulting F32 amplitudes as decimal literals, or (b) derive them with `+`, `-`, `*`, `/`, `sqrt` only, which are all exactly specified. [V - inferred from the verified lowering; I did not run the C and Metal backends to compare, so the *magnitude* of any divergence is [U].]
- **`F32.pi()` is fine.** It is the literal `3.14159265`, which rounds to `3.1415927410125732`, which is the correctly-rounded F32 of pi. [V - checked in NumPy: the literal and `float32(math.pi)` give identical bits.]
- **`F32.round` is wrong for negatives.** `def F32.round(a) = F32.floor(F32.add(a, 0.5))` [R] - that is round-half-up, not round-half-to-even, and `round(-0.5)` gives `0` where C's `roundf` gives `-1`. Minor, but do not reach for it in normalisation code.
- **No `F32.cmp`.** `bend-notes.md` records "cmp (not on F32)" [R]; use `is_lt`/`is_le`.

### If you ever do need them (another runtime, or bit-exactness)

Standard recipes, for the record. I did **not** verify these error bounds experimentally - they are the textbook figures [U].

**sqrt via Newton on the reciprocal square root** (the classic, avoids division):
```
y0 = bit_trick(x)                      # or a table/polynomial seed
y  = y0 * (1.5 - 0.5 * x * y0 * y0)    # repeat; ~2x digits per step
sqrt(x) = x * y
```
Two Newton steps from an 8-bit seed give full F32 accuracy. Goldschmidt's variant replaces the final multiply-by-`x` with a coupled iteration that pipelines better. Reference: Markstein, *IA-64 and Elementary Functions*; and Moroz et al., "Fast calculation of inverse square root with the use of magic constant", https://arxiv.org/abs/1603.04483 (gives the tuned magic constant and measured relative errors, ~1.4e-3 for the raw trick, ~5e-7 after one Newton step).

**sin/cos**: range-reduce `x` to `r in [-pi/4, pi/4]` via `k = round(x * 2/pi)`, `r = x - k*pi/2` (use a two- or three-word `pi/2` for the subtraction, or you lose all accuracy for large `x` - this is the part everyone gets wrong), then select among `+-sin(r)`, `+-cos(r)` by `k mod 4`, with the minimax polynomials
```
sin(r) ~ r * (1 + r^2*(s1 + r^2*(s2 + r^2*s3)))
cos(r) ~ 1 + r^2*(c1 + r^2*(c2 + r^2*c3))
```
Degree 7 odd / degree 6 even is enough for `< 1 ULP` in F32 over the reduced range. Canonical coefficient sets are in Cephes (http://www.netlib.org/cephes/) and in Sun's fdlibm (https://www.netlib.org/fdlibm/); **take them from there rather than deriving Taylor coefficients**, because plain Taylor needs roughly twice the degree for the same worst-case error. Muller, *Elementary Functions: Algorithms and Implementation* is the reference text.

**exp**: `x = k*ln2 + r`, `exp(x) = 2^k * exp(r)` with `r in [-ln2/2, ln2/2]` and a degree-5 minimax for `exp(r)`; `2^k` by integer exponent assembly (needs `F32.bits`/reinterpret, which Bend has as `F32.bits` -> `U32` [R], though I did not verify a reverse `U32 -> F32` bit-cast exists [U] - `U32.to_f32` is a *numeric* conversion, not a bit-cast).

**atan2**: reduce to `atan(z)` for `z in [0,1]` by the octant of `(y,x)`, degree-9 odd minimax, then add the quadrant offset. Watch the origin - Bend's own Metal shim exists because of exactly that case [R].

---

## 6. Prior art

### 6.1 Bend / HVM: nothing exists. Clean negative.

Every one of these returned zero results:

| Query | Result |
|---|---|
| `gh search repos "bend quantum simulator"` | empty |
| `gh search repos "hvm quantum"` | empty |
| `gh search repos "bend lang quantum"` | empty |
| `gh search repos "interaction combinator quantum"` | empty |
| `gh search code "qubit extension:bend"` | empty |
| `gh search code "quantum extension:bend"` | empty |
| `gh search code "hadamard extension:bend"` | empty |
| issues/PRs `repo:HigherOrderCO/Bend1 quantum` | 0 |
| issues/PRs `repo:HigherOrderCO/HVM2 quantum` | 0 |
| `quantum`/`qubit` in Bend 1 README + GUIDE | 0 occurrences |
| `quantum`/`qubit`/`matrix` in Bend 2 README + GUIDE | 0 occurrences |
| HN Algolia "bend quantum" (30 hits) | nothing connecting Bend/HVM to quantum |
| Bend 1 `examples/` (16 `.bend` files) | none quantum |

Two near-misses to rule out explicitly:

- **Bend 2's top-level `gates/` directory is not quantum gates.** It holds `_lib.ts`, `_run.ts`, `perf.ts`, `ping.ts`, `repo.ts`, `test.ts` - TypeScript CI gates. [R - confirmed against the local clone.] Likewise `tests/check/quant_tag_conversion_*.bend` and `tests/parse/quant_zero_literal.bend` are about *quantifiers* (Bend's `&0`/`&1`/`&2` quantities), not quanta.
- The only "quantum" string in `bendlang/bend` issues is https://github.com/bendlang/bend/issues/677, a speculative roadmap wishlist with one bullet "Quantum-Inspired Computing: Explore quantum computing principles for novel optimization algorithms." Not a simulator.

**Not checkable:** r/bendlang (Reddit blocked automated access from here) and X/Twitter search. [U]

**Conclusion: as of 2026-09-17 there is no quantum simulator in Bend 1, Bend 2, HVM, HVM2 or HVM3. You would be first.**

### 6.2 Bend structural templates worth reading before you write

All present in the local clone [R]:

- `bench/runtime/tree-matmul/main.bend` (180 lines) - quadtree matrix x binary-tree vector, block-recursive `mvm`, 8-way fork in `mul`, Freivalds verification pass, hand-rolled LCGs. **The closest existing thing to what you are building.** See §1.6.
- `bench/runtime/tree-bitonic/main.bend` (145 lines) - `warp`/`flow`/`bsort`/`scan` over tree levels; the butterfly pattern, and your template if you want sorted-uniform batch sampling (§4.3b).
- Also under `bench/runtime/`: `tree-radix`, `merkle`, `nbody`, `mandelbrot`, `kmeans`, `bfs`, `raytrace`.
- `demos/pure_par_sum`, `demos/pure_par_sort` - minimal balanced fork/join with `LAWS.bend` + `PROOF.bend` alongside, i.e. the proof-carrying file layout to copy.
- `tests/run/matrix_multiply_array.bend`, `tests/run/matrix_tuples.bend` - the `Array`-backed alternative to the pair-tree.

Bend 1 precedent for the "trees go fast on GPUs" argument, from its README: the immutable tree-rotation bitonic sorter ran 12.15s (Rust interp) / 0.96s (C, M3 Max) / **0.21s (RTX 4090)**, framed as "immutable tree rotations... not the type of algorithm you would expect to run fast on GPUs. However, since it uses a divide and conquer approach, which is inherently parallel..." https://github.com/HigherOrderCO/Bend1

### 6.3 Dependently typed / proof-carrying quantum simulators

Three corrections to the brief up front: **Qimaera's authors are Liliane-Joy Dandy, Emmanuel Jeandel and Vladimir Zamdzhiev** (not Wagner/Kwong/Zanzi), and **Rand's thesis is 2018, not 2021**.

#### Qimaera (Idris 2) - type safety, not verification

Paper https://arxiv.org/abs/2111.10867 ; ESOP 2023 version https://link.springer.com/chapter/10.1007/978-3-031-30044-8_19 ; repo https://github.com/zamdzhiev/Qimaera

The circuit is an **algebraic datatype of gate applications**, not a matrix:

```idris
data Unitary : Nat -> Type where
  IdGate : Unitary n
  H      : (j : Nat) -> {auto prf : (j < n) = True} -> Unitary n -> Unitary n
  P      : (p : Double) -> (j : Nat) -> {auto prf : (j < n) = True} -> Unitary n -> Unitary n
  CNOT   : (c : Nat) -> (t : Nat) ->
           {auto prf1 : (c < n) = True} -> {auto prf2 : (t < n) = True} ->
           {auto prf3 : (c /= t) = True} -> Unitary n -> Unitary n
```

The state is `Vect (2^n)` after all - close to your guess:

```idris
Matrix n m = Vect n (Vect m (Complex Double))
data SimulatedOp : Nat -> Type where
  MkSimulatedOp : {n : Nat} -> Matrix (power 2 n) 1 -> Vect n Qubit -> Nat -> SimulatedOp n
```

**What is proved: nothing semantic.** The types buy (1) index-in-bounds and control /= target, discharged by auto proof search - *"we had to do very little manual theorem proving"* - and (2) no-cloning via Idris 2 quantitative types (`(1 _ : ...)`, `LVect`). There is **no denotational semantics and no correctness theorem** relating the simulator to the intended matrix. Gate application builds the padded `2^n x 2^n` matrix and multiplies; no structural recursion over the qubit index.

One design note of theirs is directly relevant to you: *"the implicit argument `prf` may be removed from our implementation if we change the type of `j` to `Fin n` ... However, in our experience, Idris has better support for `Nat` than for `Fin` and for this reason we chose to keep the `prf` argument."* Your role-list sidesteps the whole question - there is no index to bound.

#### QWIRE - density matrices, kron plus swap conjugation

POPL 2017, https://jpaykin.github.io/papers/prz_qwire_2017.pdf ; Coq details https://jpaykin.github.io/papers/rpz_qwire_practice_2017.pdf ; Rand's 2018 thesis https://rand.cs.uchicago.edu/files/thesis.pdf

State = density matrices, circuits = superoperators. Positional gate application goes through `denote_gate'`, which applies the gate to the **first** part of the system and pads with `Id (2^n)` on the right; arbitrary positions are reached by **conjugating with swap permutations** - e.g. `swap2 0 2 = (I2 (x) swap)(swap (x) I2)(I2 (x) swap)`. So kron + permutation, not index recursion. Their own stated limits: *"we have not yet formally proved that the denotation of every circuit is a well-formed superoperator over density matrices"*, and *"density matrices are always exponential in the size of the corresponding circuit"*.

#### SQIR / VOQC - this is the crux, with the exact lemmas

VOQC: https://arxiv.org/abs/1912.02250 (POPL 2021). Proof techniques: https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2021.21 (free text https://par.nsf.gov/servlets/purl/10253287). Repos https://github.com/inQWIRE/SQIR , https://github.com/inQWIRE/QuantumLib

`Matrix m n` in QuantumLib is a **function** `nat -> nat -> C` plus a `WF_Matrix` side condition, not inductive data. `dim` is a phantom index and qubit args are plain `nat`.

**The `I_(2^k) (x) U (x) I_(2^(n-k-1))` identity you asked for, verbatim from `QuantumLib/Pad.v`:**

```coq
Definition pad {n} (start dim : nat) (A : Square (2^n)) : Square (2^dim) :=
  if start + n <=? dim then I (2^start) ⊗ A ⊗ I (2^(dim - (start + n))) else Zero.

Definition pad_u (dim n : nat) (u : Square 2) : Square (2^dim) := @pad 1 n dim u.

Definition pad_ctrl (dim m n: nat) (u: Square 2) :=
  if (m <? n) then
    @pad (1+(n-m-1)+1) m dim (∣1⟩⟨1∣ ⊗ I (2^(n-m-1)) ⊗ u .+ ∣0⟩⟨0∣ ⊗ I (2^(n-m-1)) ⊗ I 2)
  else if (n <? m) then
    @pad (1+(m-n-1)+1) n dim (u ⊗ I (2^(m-n-1)) ⊗ ∣1⟩⟨1∣ .+ I 2 ⊗ I (2^(m-n-1)) ⊗ ∣0⟩⟨0∣)
  else Zero.
```

**Note `pad_ctrl` has an explicit `m <? n` / `n <? m` case split - the control-above-vs-below-target problem, handled by writing the two kron expressions out separately.** That is exactly the duplication your role walk eliminates (§1.4). Out-of-bounds gates denote to `Zero`; from ITP 2021: *"The denotation of any gate applied to an out-of-bounds qubit is the zero matrix, ensuring that a circuit corresponds to a zero matrix if and only if it is ill-formed."* Available algebraic lemmas: `pad_mult`, `pad_id`, `pad_unitary`, `pad_ctrl_unitary`, `pad_A_B_commutes`, `pad_A_ctrl_commutes`, `pad_ctrl_ctrl_commutes`.

**The structurally recursive half, `QuantumLib/VectorStates.v`** - this *is* your tree, written as a right-nested kron:

```coq
Fixpoint f_to_vec (n : nat) (f : nat -> bool) : Vector (2^n) :=
  match n with
  | 0    => I 1
  | S n' => (f_to_vec n' f) ⊗ ∣ f n' ⟩
  end.

Fixpoint vkron n (f : nat -> Vector 2) : Vector (2 ^ n) :=
  match n with | 0 => I 1 | S n' => vkron n' f ⊗ f n' end.
```

**The bridge lemma - this is the one to lift:**

```coq
Lemma f_to_vec_split : forall (base n i : nat) (f : nat -> bool),
  i < n ->
  f_to_vec n f = (f_to_vec i f) ⊗ ∣ f i ⟩ ⊗ (f_to_vec (n - 1 - i) (shift f (i + 1))).
```

proved by `induction n`. And the gate-at-index-k correctness statements, verbatim:

```coq
Lemma f_to_vec_σx : forall (n i : nat) (f : nat -> bool),
  i < n -> (pad_u n i σx) × (f_to_vec n f) = f_to_vec n (update f i (¬ (f i))).

Lemma f_to_vec_cnot : forall (n i j : nat) (f : nat -> bool),
  i < n -> j < n -> i <> j ->
  (pad_ctrl n i j σx) × (f_to_vec n f) = f_to_vec n (update f j (f j ⊕ f i)).

Lemma f_to_vec_hadamard : forall (n i : nat) (f : nat -> bool),
  (i < n)%nat ->
  (pad_u n i hadamard) × (f_to_vec n f)
      = /√2 .* ((f_to_vec n (update f i false)) .+
                (Cexp ((f i) * PI)) .* f_to_vec n (update f i true)).
```

**Answer to "structural recursion over the index, or matrix algebra?" - both, glued by one lemma.** The proof of `f_to_vec_sigma_x` is literally `intros. unfold pad_u, pad. rewrite (f_to_vec_split 0 n i f H). repad.` - unfold the *operator* into its three-factor kron, split the *state* at index `i` (the inductive part), then `repad` does the dimension bookkeeping to line the two up. `repad`/`gridify` are Ltac tactics doing `bdestruct_all; Msimpl_light; remember_differences; hypothesize_dims; clear_dups; fill_differences`.

**This is the pattern to lift, and your design skips half of it.** Your `Q(n)` tree *is* `f_to_vec`/`vkron`; your split-at-level-`k` *is* `f_to_vec_split` - except in your design it is **definitional, not a lemma**, because the tree literally *is* a pair of subtrees at every level. `repad`/`gridify` disappear entirely. That is the concrete technical advantage of the indexed tree over a function-encoded vector, stated in terms a reviewer would recognise.

Their honest caveat about the abstraction: *"The f_to_vec abstraction is simple and easy to use, but not universally applicable: Not all quantum algorithms produce basis states ... and reasoning about 2^d terms of the form |i1...id> is no easier than reasoning directly about matrices."*

And a warning you will hit: *"the dimensions stored in the type may be 'out of sync' with the structure of the expression itself. For example ... |0> (x) |0> may be annotated with the type `Vector 4`, although rewrite rules expect it to be of the form `Vector (2 * 2)`."* In Bend, `Q(1n+p)` vs `Q(p) & Q(p)` is the same issue; **plan the normal form up front.** My verified prototype avoids it by never mentioning `2^n` at all - the depth `n` is the only index, and `2^n` is implicit in the shape.

VOQC's correctness statement is semantic equality of denoted matrices: an optimisation is correct iff `uc_eval c = uc_eval (opt c)`.

#### Everything else

| System | Assistant | State representation | What is proved |
|---|---|---|---|
| **CoqQ** (POPL 2023) | Coq + MathComp | abstract **Hilbert spaces** + labelled Dirac notation; not indexed by `2^n` | program logic proved sound wrt denotational semantics |
| **Qbricks** (ESOP 2021) | Why3 + SMT | **path sums**; explicitly avoids the exponential state vector | hybrid quantum Hoare logic, highly automated |
| **QHLProver** | Isabelle/HOL | explicit matrices | quantum Hoare logic soundness |
| **qrhl-tool** | Isabelle/HOL | quantum relational Hoare logic | relational verification |

https://arxiv.org/abs/2207.11350 , https://github.com/coq-quantum/CoqQ , https://arxiv.org/abs/2003.05841 , https://arxiv.org/pdf/2505.08633 . Surveys: https://arxiv.org/abs/2109.06493 , https://arxiv.org/abs/2110.01320

**None of these prove gate application by structural recursion over the qubit index.**

**Agda: nothing found** [U - negative result from searching "Agda quantum simulator", "Agda qubit", "Agda quantum formalization linear algebra"]. The closest relevant artefact is `functional-linear-algebra`, *"Formalizing linear algebra in Agda by representing matrices as functions"* - the same `nat -> nat -> C` trick QuantumLib uses. https://github.com/ryanorendorff/functional-linear-algebra

**Lean 4: active, but no simulator and no index-recursive gate proof** [U for the newest repos - READMEs and abstracts read, not proof scripts]. `inQWIRE/LeanQuantum` (now `Quantumlib.lean`, last pushed 2026-07-14) has `hadamard`, `σx/σy/σz`, `phaseShift`, `rotate` (U3), `cnot`, `swap`, `controlM`, and notably **`hadamardK k`** - a k-fold tensor product, i.e. a structural recursion over qubit count - plus Pauli operators as `structure Pauli (n : ℕ) where m : ZMod 4; z : BitVec n; x : BitVec n`. https://github.com/inQWIRE/LeanQuantum . Also `QHilbert` (https://github.com/jam-khan/QHilbert), `Lean-QEC`, `QECLean`, and https://arxiv.org/pdf/2607.05492

**Bottom line: no proof-assistant development types the state as a qubit-indexed binary tree and proves gate application by induction on it.** SQIR's `f_to_vec` + `f_to_vec_split` is the closest and is the skeleton to lift. Your contributions over SQIR would be (a) no out-of-bounds `Zero` case, (b) a tree instead of a function-encoded vector, so the split is definitional and the dimension tactics vanish, (c) F32 or exact-ring amplitudes, which **no formalization has** - every one above uses exact R/C or an algebraic ring. Budget accordingly: with F32 you would be proving things about a representation nobody has formalized, and §1.7 says the answer is "you can't". With the exact ring of §3, you can.

---

## 7. Numerical guidance for F32 state vectors

### Memory per amplitude

A complex F32 amplitude is **8 bytes** (two 4-byte floats); complex F64 is **16 bytes**. Dense state vector = `2^n * bytes`:

| n | complex64 (8 B) | complex128 (16 B) |
|---|---|---|
| 20 | 8 MiB | 16 MiB |
| 25 | 256 MiB | 512 MiB |
| 30 | 8 GiB | 16 GiB |
| 32 | 32 GiB | 64 GiB |
| 34 | 128 GiB | 256 GiB |
| 40 | 8 TiB | 16 TiB |

**Bend-specific overhead warning, and it is much worse than I first guessed. Measured** [V]:

| n | amplitudes | flat complex64 would be | **actual max RSS (JS backend)** | **bytes per amplitude** | wall time |
|---|---|---|---|---|---|
| 20 | 1 048 576 | 8 MiB | **2.35 GB** | ~2 240 | 3.2 s |
| 24 | 16 777 216 | 128 MiB | **25.2 GB** | ~1 500 | 121 s (104 s of it in `sys`) |

That is a **~190-280x** blow-up over the 8-bytes-per-amplitude ideal, and the n=24 run spent more time in the kernel than in userspace, i.e. it was thrashing. Norm came out correct (`0.99999976`, about 4 ULP, and *not* growing from n=20 to n=24) and the amplitudes were right (`2^-10` and `2^-12` for uniform superpositions), so this is a memory-representation problem, not a correctness problem.

**Caveat on how to read this:** these are **JS-backend** numbers, where every `&`-pair becomes a JS object and every `Nat` a `BigInt`, and max RSS includes uncollected garbage. The native C backend should be dramatically better - Bend's C target packs machine-word arrays as "one flat block of packed 32-bit cells" [R - `bend-notes.md`] - and I did **not** build it. [U] But the direction is unambiguous and the magnitude is large enough that it should drive the design:

- **The `Q(n)` pair-nest is a memory hog on at least one shipped backend.** `2^n - 1` internal cells, each an allocated pair.
- **Consider an `Array`-backed layout** (`tests/run/matrix_multiply_array.bend` is the template) or a hybrid: pair-tree for the top `k` levels where the parallel forks happen, flat arrays for the leaf blocks. That keeps the balanced fork/join structure and the pairwise summation while collapsing the per-amplitude overhead.
- **Benchmark the native C backend before committing to either.** This is now the top open engineering question, and it is a single `bend` invocation away.

Also: one GPU per program, and the Metal GPU span defaults to 2 GB [R - `bend-notes.md`], which caps a GPU-resident state around n = 26-27 even at the *ideal* 8 bytes per amplitude - and far lower at the overhead measured above.


### F32 facts, computed here [V]

- significand 24 bits; `eps = 2^-24 = 5.9604645e-08` (half-ULP), `2^-23 = 1.1920929e-07` (ULP at 1.0)
- min normal `1.1754944e-38`, min subnormal `1e-45`, max `3.4028235e+38`

### Underflow of probabilities is not a real risk

For a uniform superposition the amplitude is `2^(-n/2)` and the probability `2^-n` [V]:

| n | amplitude | `|amp|^2` | status |
|---|---|---|---|
| 30 | 3.05e-05 | 9.31e-10 | fine |
| 60 | 9.31e-10 | 8.67e-19 | fine |
| 120 | 8.67e-19 | 7.52e-37 | fine |
| 127 | 7.67e-20 | 5.88e-39 | **subnormal** |
| 150 | 2.65e-23 | 0 | **zero** |

Probabilities go subnormal around **n = 127** and flush to zero around **n = 150**. You will run out of memory at n ~ 30. So: ignore this. It matters only for *individual small amplitudes* in a highly peaked state, not for the uniform case.

### Where F32 error actually shows up

The `0.49999997` in my Toffoli run [V] is the honest illustration. `1/sqrt(2)` in F32 is `0.70710676908493042`, which is the correctly-rounded value (relative error 1.7e-8), and its square is `0.49999997019767761`, not `0.5`. Two H gates therefore already leave you 3e-8 off. This is irreducible: `1/sqrt(2)` is irrational and `H`'s factor appears in every Clifford circuit. Note the literal `0.70710677` in the prototype *is* optimal - it and `float32(1)/sqrt(float32(2))` have identical bits [V]. There is no sloppiness to fix there.

### Error growth: variance linear in depth, so error norm grows as sqrt(depth)

There *is* a proper citation for this, and it is specifically about low-precision state-vector simulation.

**Betelu, "The limits of quantum circuit simulation with low precision arithmetic", arXiv:2005.13392** - https://arxiv.org/abs/2005.13392 . Let `|eps_t>` be the cumulative error vector and `|tau_t>` the per-gate rounding error. Then

> `|eps_{t+1}> = U_t |eps_t> + |tau_t>`  (Eq. 14)
>
> "Because the gate is unitary, ||U_t|eps_t>||^2 = |||eps_t>||^2, and assuming the errors are random, independent, identically distributed and unbiased, the variances can be added ... thus the cumulative variance increases linearly as a first approximation."

So `sigma^2 ~ eps_c^2 * G` and **error norm ~ sqrt(G) * u**. Max gates for a tolerance: `G_random < sigma^2 / eps_c^2` (Eq. 16). Fidelity link: `Phi >= (1 - sigma^2/2)^2`.

**Rigorous numerical-analysis foundation:** Higham & Mary, "A New Approach to Probabilistic Rounding Error Analysis", SIAM J. Sci. Comput. 41(5):A2815-A2835, 2019 - https://eprints.maths.manchester.ac.uk/2673/1/paper.pdf . Their Theorem 2.4 bounds a product of `n` independent mean-zero roundings by `gamma_n(lambda) = lambda*sqrt(n)*u + O(u^2)` with probability `>= 1 - 2exp(-lambda^2(1-u)^2/2)`, and the abstract states it "provides, for the first time, a rigorous foundation for the rule of thumb that 'one can take the square root of an error constant because of statistical effects in rounding error propagation'". `lambda = 2.26` sufficed in all their tests.

**Deterministic worst case is linear, not exponential:** Childs, *Lecture Notes on Quantum Algorithms*, Lemma 2.2 - if `||U_i - V_i|| <= eps` then `||U_t...U_1 - V_t...V_1|| <= t*eps`. https://www.cs.umd.edu/~amchilds/qa/qa.pdf

**Measured** (12 qubits, random SU(2) + CNOT layers, complex64 vs complex128 reference on an identical gate sequence) [V - measured in this session]:

| depth | L2 `||psi32 - psi64||` | `sqrt(d)*u` | ratio |
|---|---|---|---|
| 10 | 1.52e-07 | 1.89e-07 | 0.81 |
| 100 | 4.38e-07 | 5.96e-07 | 0.74 |
| 1 000 | 1.43e-06 | 1.89e-06 | 0.76 |
| 10 000 | 4.62e-06 | 5.96e-06 | 0.77 |
| 100 000 | 1.44e-05 | 1.89e-05 | 0.76 |

`L2 ~ 0.76 * sqrt(d) * u`, constant to within 4% over four decades. Extrapolating: **L2 error reaches 1e-3 at depth ~4.6e8; infidelity reaches 1e-3 at depth ~1e12.** F32 will not be your limit - wall-clock and memory will.

**The one regime where this fails: biased error.** Betelu, §IV-C: "Unlike the errors studied in previous sections, biased errors do not tend to cancel each other", and then `sigma^2` grows as `O(G^2)`, cutting the usable depth to ~1.7e4. Measured counterexample - apply `Rz(2*pi/W)` exactly `W` times, which should return exactly to 1 [V]:

| W | `|z-1|` in complex64 | `sqrt(W)*u` | ratio to sqrt law |
|---|---|---|---|
| 256 | 1.38e-08 | 9.54e-07 | 0.01 (fine) |
| 4 096 | 6.76e-05 | 3.82e-06 | **18x** |
| 65 536 | 3.01e-04 | 1.53e-05 | **20x** |

Small-angle rotations - QFT phase gates, Trotter steps with small `dt` - break the sqrt law by one to two orders of magnitude. Betelu also notes which gates are *error-free*: "NOT, CNOT, SWAP and phase gates with angle pi/2^k, k < A are error-free because they basically involve memory swaps, sign changes or integer changes of the register." So a Clifford-heavy circuit is far safer than a QFT.

**Literature anchor for the magnitude:** Morningstar et al., TPU Floquet simulation in single precision, https://ar5iv.labs.arxiv.org/html/2111.08044 - "our simulations are accurate up to an overlap error of about 10^-7 at early times (as expected with 32-bit precision), and at the latest time t=10^5 the overlap error reaches 10^-3", at roughly 4e6 two-qubit gates.

### Who actually ships F32

- **qsim (Google)**: float32 is not merely the default, it is **the only option through the Python API** - `qsimcirq/qsim_simulator.py` raises `TypeError("initial_state vector must have dtype np.complex64.")` [R]. It also exposes a `denormals_are_zeros` flush-to-zero flag. https://github.com/quantumlib/qsim . The memory formula in Google's own hardware guide is "memory required = 8 * 2^N bytes", i.e. complex64: 8 GB laptop -> 29 qubits, A100 40 GB -> 32, A100 80 GB -> 33. https://quantumai.google/qsim/choose_hw
- **qFlex** ran at "an average performance of 281 Pflop/s (true single precision)" on Summit. https://arxiv.org/abs/1905.00444
- **NVIDIA cuStateVec** supports both; "By default, computation is executed using the corresponding precision of the state vector, double float (FP64) for complex128 and single float (FP32) for complex64." https://docs.nvidia.com/cuda/archive/13.1.0/cuquantum/25.09.0/custatevec/custatevec/overview.html
- **Qiskit Aer** has `precision="single"|"double"`, **defaulting to double**, with no accuracy caveat documented. https://qiskit.github.io/qiskit-aer/stubs/qiskit_aer.AerSimulator.html

One dissenting study claims "FP32 exhibits measurable degradation for circuits exceeding 20 qubits with depth greater than 50 gates" (https://arxiv.org/html/2604.03816). **Be sceptical of it**: its bound multiplies by the full dimension `2^n`, which contradicts norm preservation (a single-qubit gate touches 2 amplitudes, not `2^n`), and its own worked example yields a vacuous bound `> 1`. Its reported Bell-state fidelity of 0.939 is implausibly low for *any* exact simulator, suggesting its measurement is dominated by something other than F32 rounding. [U]

### The precision problem that actually matters: summing `|a|^2`

This is the one genuine F32 hazard at reachable `n`, and I had it wrong in my first pass.

Summing `2^n` **nonnegative** values is exactly the case where the `sqrt(n)` statistical benefit evaporates. Higham & Mary flag it explicitly:

> "we identified two situations involving inner products in which the underlying assumptions are not valid and the bounds do not apply: **large nonnegative vectors, for which the rounding errors eventually have nonzero mean**, and constant vectors for which the rounding errors are dependent."

Naive sequential summation has the deterministic bound `~N*u`. Measured on a Haar-random state with a float32 accumulator, true value 1 [V]:

| n | naive sequential relerr | pairwise | Kahan |
|---|---|---|---|
| 16 | 2.50e-06 | exactly `1.0f` | exactly `1.0f` |
| 20 | 1.18e-04 | exactly `1.0f` | exactly `1.0f` |
| 22 | 1.46e-03 | exactly `1.0f` | exactly `1.0f` |
| 24 | **2.31e-02** | exactly `1.0f` | exactly `1.0f` |

**At n = 24 a naive float32 sum of probabilities is 2.3% wrong.** Pairwise and Kahan both land on exactly `1.0f`.

**This is a strong, quantitative argument for the tree.** A structurally recursive tree reduction

```
norm2(Leaf a)      = re^2 + im^2
norm2(Node(l, r))  = norm2(l) + norm2(r)
```

***is*** the pairwise summation algorithm. Its error is `O(log2(N) * u)` instead of `O(N * u)` - about four orders of magnitude better at n = 24, five at n = 30 - and you get it **for free, structurally, with no Kahan compensation and no F64 accumulator** (which Bend could not give you anyway, since there is no F64). My own measured `norm2 = 0.99999994` at every n from 8 to 16 [V] is this effect: the tree fold is pairwise by construction.

Rule: **every reduction over the state vector** - norm, total probability, expectation values, marginal probabilities for sampling - must be the tree fold, never a flattened left-to-right accumulation. In Bend this is the path of least resistance anyway, which is a rare case of the idiomatic choice also being the numerically correct one.

### Two more hazards worth designing around

**The `1/sqrt(2)` constant does not drift** [V - measured]. Repeated multiplication by `f32(1/sqrt(2))` has relative error 1.71e-08 after one multiply, 5.96e-08 after two, then **saturates at 1.19e-07 (2 ulp) and stays there out to 200 multiplications**, because the exact target `2^(-k/2)` is a dyadic for even `k`, so each rounding snaps back to the nearest representable neighbour. Building `|+>^(x)n` with `n` Hadamards gives `||psi|| - 1 = -1.19e-07` *independent of n* for n = 4..24. This corroborates my own n=8..16 runs. Implementation rule: precompute `c = f32(1/sqrt(2))` **once** and evaluate `(a+b)*c`, `(a-b)*c` - two roundings per output. Do **not** write `a/sqrt(2) +- b/sqrt(2)` (four roundings plus a divide), and do not recompute `sqrt(2)` per gate.

**Never let a rounded amplitude drive a structural decision.** This is the failure mode that kills tree/DD simulators, and Zulehner, Hillmich & Wille document it (https://arxiv.org/abs/1911.12691):

> "If the real and the imaginary part of an edge weight are now close to 0 (in the interval [-eps, eps]), the weight is rounded to 0. By this, a sub-tree of the decision diagram is possibly pruned by setting several entries in the matrix to zero - ending up with a huge round-off error and numerical instabilities."

Their two mitigations, both applicable if you ever add sharing or zero-subtree pruning: (1) normalise each node by its largest-magnitude child, so "it is guaranteed that all edge weights in the decision diagram have an absolute value between 0 and 1 ... making it less likely that a factor unintendedly rounds to 0"; (2) defer rounding - "we look up complex numbers as late as possible, all computations are conducted with maximal precision."

**For a plain dense tree with no pruning, this risk is zero.** Catastrophic cancellation in interference leaves an absolute residue of order `u*|a|`, whose induced probability error is `O(u^2) ~ 3.5e-15` - below F32 resolution and irrelevant to sampling. That is a reason to keep the dense tree and not chase compression.

### Measured scaling and norm drift of the prototype [V]

I ran the verified prototype (H on q0, then CNOT ctrl=q0 targ=q(n-1), then a parallel `norm2` fold) at increasing `n` on the **sequential JS backend**:

| n | amplitudes | wall time | `norm2` |
|---|---|---|---|
| 8 | 256 | 0.08 s | 0.99999994 |
| 12 | 4 096 | 0.14 s | 0.99999994 |
| 14 | 16 384 | 0.29 s | 0.99999994 |
| 16 | 65 536 | 0.91 s | 0.99999994 |

Two things worth having:

- **The norm is 1 - 2^-24 at every size**, i.e. off by exactly one ULP, and it does **not** degrade from n=8 to n=16. The error comes entirely from `1/sqrt(2)` not being representable, not from accumulation. This is direct evidence for the "errors accumulate, they do not amplify" claim above.
- Time grows roughly with `2^n` (16x the amplitudes from n=12 to n=16 cost 6.5x the wall time, the gap being interpreter start-up amortising). This is the JS target, which "runs on one core and has no graphics or audio" and "ignores all of this and runs sequentially" [R]. Native C and the GPU are the real targets; Bend's own published figures for a comparable immutable-tree workload were 0.96 s (C, M3 Max) vs 0.21 s (RTX 4090) [R - Bend 1 README].

### Do not renormalize defensively

Renormalizing after every gate costs a full `O(2^n)` pass and a `sqrt`, and it buys almost nothing - **it removes only the radial component of the error, measured at about 8% of the total** (at depth 1e5, norm drift was 1.1e-06 while the actual L2 error was 1.44e-05) [V]. The error is almost entirely tangential: phase and direction, not magnitude. Unitarity is nearly preserved for free.

Betelu is explicit about this: renormalise *"only if the normalization condition departs from unity by a prescribed fraction"*, and *"It was found empirically that when the coefficients of |psi> are random, this procedure is not necessary at all."* Renormalisation is his remedy for the **biased** error regime specifically, to bring behaviour back toward the `sqrt(G)` law from the `G` law. https://arxiv.org/abs/2005.13392

**Recommendation:** do not renormalise periodically. Renormalise once after **measurement collapse**, where the division by `sqrt(p)` is mathematically required rather than cosmetic - Zulehner & Wille renormalise exactly there and nowhere else [R] - and once before sampling. Instead, **use `||psi|| - 1` as a bias diagnostic**: in the unbiased regime it should stay within a small multiple of `sqrt(depth) * u`; if it exceeds ~`10 * sqrt(depth) * u` you have a systematic bug (a small-angle gate, a mis-rounded constant, a non-unitary gate matrix), not a precision limit. A defensive renormalise would have hidden exactly that signal.

---

## 8. Recommendation

### The build order

1. **Keep the verified prototype's core** (`Q(n)` as a type-level pair-nest, roles list, `apply`/`mix`). It is correct, it is 138 lines, and the hard cases are tested. Do not redesign the data structure - it has published antecedents (§1.3b) and the affine/parallel properties you need.
2. **Replace hand-built roles lists with smart constructors** (`single`, `controlled`, `multi_controlled`), structurally recursive on `n`, plus a `law` that each emits exactly `n` roles. This closes the silent-drop hole in §1.7 without needing an indexed roles type (which does not typecheck - verified).
3. **Refactor `mix` into the fused butterfly** that consumes `l` and `r` exactly once and returns both new subtrees. The prototype already does this; keep it, and resist the `+v`-clone shape that Bend's own `tree-matmul` uses (§1.6).
4. **Add measurement**: the `norm2` tree fold (already written and verified), then branch selection, zeroing and rescaling. This is the single biggest gap versus "minimum complete" (§2.5, item 5).
5. **Add the PRNG and batch sampling**: xorshift32 or the `lowbias32`-family finalizer, seeded from `IO.now()`, `U32 -> F32` by `(x >> 8) * 2^-24`, and batch sampling by **splitting a list of uniforms at each node** (§4.3b) - no binomial sampler needed. All the primitives are verified working.
6. **Then decide the amplitude type.** This is the real fork in the road.

### The one decision that matters: F32 or the exact ring

| | F32 pair | exact `D[omega]` (4 ints + shared `k`) |
|---|---|---|
| lines for the amplitude layer | ~20 | ~128 (measured) |
| provable about amplitudes | **nothing** (F32 is axiomatic) | `X.X = id`, `H.H = id`, unitarity, `k <= #H`, `\|coeff\| <= 2^(k/2)` |
| gate set | anything, including `Rz(theta)` | Clifford+T only |
| multiplication needed | yes | **none** |
| depth budget | ~1e8 layers before 1e-3 error | ~500 T gates (48-bit Nat), unbounded for Clifford-only |
| memory per amplitude | 8 bytes | 4 Nats (or 8 with the difference-pair sign) |
| prior art to diff against | everything | SliQSim, newsynth |

**If the goal is "a simulator", take F32.** It is smaller, it handles arbitrary rotations, and §7 says precision will not be your limiting factor.

**If the goal is "a simulator whose correctness the checker verifies" - which is the only reason to pick Bend 2 over Python - take the exact ring.** With F32 the proof story is confined to shape and termination, which the types already give you for free without any proof text. The exact ring is where `LAWS.bend` gets something interesting to say. Recommended concretely: the **difference-pair sign representation** (§3.9 option C), because `add` becomes componentwise `Nat.add` and `Nat.add_comm` is the one arithmetic law base already ships.

A reasonable hedge: build the tree and gate walk generic over an amplitude interface, implement F32 first to get a working simulator, then add the exact ring as a second instance and prove the laws against that one. Bend's compile-time `~` templates are the mechanism for this (each instantiation compiles to its own copy, so there is no closure cost).

### What to measure before committing

- **Native-backend memory, urgently.** On the JS backend the pair-tree costs **~1 500-2 240 bytes per amplitude** (2.35 GB at n=20, 25.2 GB at n=24), a ~200x blow-up over the 8-byte ideal, with the n=24 run thrashing. Whether the C backend collapses that is the single most important unknown, and it is one `bend` invocation away. If it does not, switch to an `Array`-backed or hybrid layout (pair-tree for the top levels where the forks are, flat arrays for leaf blocks).
- **Native and GPU throughput.** All my timings are the sequential JS backend. The C and Metal backends are the real target and I did not build them.
- **Whether the parallel `Skip` forks actually engage the scheduler** without a `!` mark - issue #767 was closed the same day but the underlying question is recorded as untested in `bend-notes.md`.

## 9. Things I could not verify

- **Sabry 2003's actual state representation.** ACM DL is paywalled and the Indiana mirror now redirects to a department page (I fetched it and got HTML). The "dictionary mapping values to probabilities" characterisation is search-derived. Quipper - same lineage, verified from source - is the better citation.
- **The exact verbatim wording** of the Wille/Hillmich/Burgholzer role classification. ACM DL returns HTTP 403 to automated fetches; use the arXiv version (arXiv:2108.07027) to confirm before quoting it in writing.
- **Whether Bend 2 supports value-indexed inductive families** (which would allow a `Data`-kinded length-indexed roles type). I stopped after the `Type`-vs-`Data` failure rather than guess.
- **Cross-backend F32 divergence magnitude** for `sin`/`cos`/`exp`/`log`/`pow`. The lowering differs (libm-in-double vs Metal `precise::` vs `Math.fround`), so divergence is possible in principle; I did not build the C or Metal backends to compare. `sqrt` is provably safe.
- **Reddit r/bendlang and X/Twitter** for Bend quantum discussion - both blocked automated access.
- **AutoQ's leaf encoding being exactly `(a,b,c,d)+k`.** The `Z^5` alphabet is confirmed; the precise correspondence to `D[omega]` is not.
- **Proof-to-code line ratio** for this kind of development in Bend. The 3-10x guess has no data behind it.
