# Bend (bend-lang.com) - research notes

Compiled 2026-09-17, the day Bend 2 launched. Sources: the `bendlang/bend` repo at version 2.0.5 (cloned and read: README, AGENTS.md, GUIDE.md, base.bend, bend.lean, main.ts, comp.ts headers, demos, bench pins, both papers), bend-lang.com and its install script, the GitHub API, crates.io, Taelin's X posts via the oembed endpoint, and both Hacker News threads via the Algolia API. I also ran the checker, the JS backend, and native CPU and GPU builds on this Mac from a scratchpad clone.

Evidence markers used below:

- [V] verified by running it here
- [R] read in a primary source (repo, paper, site, API)
- [S] search-result excerpt or third-party text that I could not open directly
- [M] from memory, not verified this session

## TL;DR

- Bend was rebuilt from scratch. Bend 2 launched 2026-09-17 (announcement post 20:20 UTC, repo pushed 23:40 UTC). [R]
- Bend 1 (2024) was a Rust language on HVM2, an interaction-combinator runtime, pitched as "Python that runs on GPUs". It is archived as `HigherOrderCO/Bend1`; its last release was 0.2.38 on 2025-02-23. [R]
- Bend 2 is a dependently typed, affine, Python-syntax language whose type checker is a proof checker. It is written in TypeScript and runs on Bun. It compiles to one C file that runs on CPU threads and on Metal or CUDA GPUs, and to sequential JavaScript. HVM and interaction nets are not used at all. [R]
- The pitch: humans write rules in `LAWS.bend`, an AI writes code plus `PROOF.bend`, and `bend PROOF.bend` fails until every law is proven. "LAWS.bend is AGENTS.md backed by proof." [R]
- Claims: near-C single-thread speed, ~10x on 16 cores, 50x to 75x on a GPU for uniform numeric work, and a checker 10x to 100x faster than Lean on synthetic files. My own runs on an M5 Pro reproduced the runtime shape: 1.1x to 1.2x of C on one thread, 12x to 17x on 18 threads, 49x to 75x on the integrated GPU. [V]
- It is day one. Verbose, tiny standard library, no tooling, F32-only floats that cannot be reasoned about, a compiler that is "99% AI-written and not fully audited", squashed git history, and 13 bugs filed within hours. [R]

## Identity and links

| item | value |
|---|---|
| site | https://bend-lang.com (higherorderco.com now 301-redirects here) |
| repo | https://github.com/bendlang/bend (was HigherOrderCO/Bend; created 2023-08-29, so the star count is inherited) |
| license | Apache 2.0 |
| version | 2.0.5 (`/dl/latest.json`); HN commenters saw 2.0.4 earlier in the day; the bug template placeholder says 2.0.0 |
| stars / forks | 20,374 stars, 530 forks at time of writing |
| issues / PRs | 290 issues total, 14 open; 501 PRs total, 5 open; 23 issues opened in 2026, 13 of them on launch day |
| history | one commit, "Bend 2.0.5", author Victor Taelin; no releases, no tags |
| languages (bytes) | TypeScript 486,853; C 133,179; Typst 58,210; JavaScript 58,084; TeX 12,222; HTML 2,887 |
| topics | bend, cuda, dependent-types, gpu, metal, parallel, programming-language, proof, theorem-proving |
| community | Discord https://discord.bend-lang.com, X @bendlang, Reddit r/bendlang |
| hub | https://hub.bend-lang.com (BendHub package registry) |
| paid tool | https://bend-lang.com/bender (Bender proving agent) |
| guide | `guide/GUIDE.md`, also `bend guide` |
| papers | `paper/BendTT.pdf` (type theory), `paper/BendRT.pdf` (runtime) |
| formalization | `bend2/bend.lean` |

A sibling repo `bendlang/bend-lang.com` (site, installer, hub, release tooling) is referenced in AGENTS.md but only `bend` and `.github` are public in the org. [R]

## Repo layout (from AGENTS.md and the tree)

```
bend2/bend.ts       the language: parser, theory, checker (126 KB) - "99% human-designed and audited"
bend2/comp.ts       the compiler and the runtimes: C, Metal, CUDA, JS (180 KB) - "mostly written by AIs ... bugs ARE expected"
bend2/main.ts       the CLI (18 KB); imported, it is the .bend loader for bun and node
bend2/base.bend     the base library (62 KB): 22 types, 373 defs, 72 laws (the law count includes opaque handle types and IO signatures declared as laws)
bend2/bend.lean     the core, mechanized in Lean 4: 20,981 lines, 1,111 theorems, zero `sorry`
bend2/effs/         one .c and one .js file per IO effect (audio, chan, file, get_env, now, print, sleep, spawn, tcp, udp, window, write)
bend2/pack/         package.json (only devDependency: @types/bun), tsconfig, bun.lock
bend2/docs/         Typst sources of the papers, the launch film, gen_pins.ts, gen_charts.ts, gen_gifs.ts, a Sublime syntax
bench/runtime/      16 benches, each with main.bend and twins in C, TS, Lean, plus _pin_/ result files
bench/checker/      5 benches, each with main.bend and rivals in Agda, Lean, Isabelle (.thy), Rocq (.v)
tests/              1,328 files in 24 namespaces; each test ends in `#|` lines its run must print
gates/              test.ts, perf.ts, repo.ts (allow list and token caps per file), ping.ts, _run.ts; run on a "mini cluster" (48 Mac minis per AGENTS.md)
demos/              16 demos, each with main.bend, LAWS.bend, PROOF.bend
evals/              20 proof tasks in tiers cake / easy / firm / hard / hell, "the models' arena"
guide/GUIDE.md      the whole language, 24 KB
media/              gifs and the intro film
```

Test namespaces and file counts: base 27, check 201, compile 101, comptime 32, cost 5, eval 39, flatten 240, gfx 3, grade 17, halt 35, import 19, io 126, page 23, parse 140, printer 7, proof 75, reg 93, rfc 9, run 67, show 8, spec 15, state 16, stats 5, stuck 25. [R]

## The language (Bend 2)

Everything in this section is from GUIDE.md, base.bend, and the bend.ts header. [R]

### Hello world

```python
import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Hello, world!")
```

`bend hello.bend` checks the file and runs `main` on the JS backend. A `main` returning `IO` runs compiled; one returning a value is normalized by the checker and printed; a file without `main` just checks.

### Types and functions

```python
type Shape is Data:
  Circle{r: U32}
  Square{s: U32}

def area(x: Shape) -> U32:
  match x:
    case Circle{+r}:
      (3 * r * r : U32)
    case Square{+s}:
      (s * s : U32)
```

- `is Data` means values may be copied; `is Type` means they cannot.
- Variables are affine by default: used at most once. `+x` makes a variable reusable, which requires its type to be `Data`. `-x` erases it (types and proofs only; deleted by the compiler).
- Almost nothing is inferred. A `let` must be inferable, so literals need annotations: `x = {3 : U32}`.
- Operators are sugar over `T.add` etc. and need the `: T` inside parens: `(a + b * c : U32)`. Without `: T` they belong to `Nat`. Operators need spaces on both sides. `==` is only a type; value equality is `T.is_eq(a, b)`.

### Closures

Functions are values, but a closure is affine: it can be called at most once, even if everything it captures is `Data`. Only top-level defs can be called freely. Partial applications like `U32.add(2)` are closures too.

### Recursion and termination

- Termination is mandatory and checked structurally: recursive calls must pass a smaller part of a pattern-matched parameter. Arguments are read left to right; put the shrinking parameter first (issue #770 documents the position sensitivity).
- No mutual recursion. Two mutually recursive functions become one def with a selector argument.
- `U32` has no `1+p` pattern, so loop counters are `Nat`. A `Nat` is still a machine word at runtime; a program aborts past 2^48 - 1.
- There is no `if`. A branch is a `match` on `True{}` and `False{}`.
- `match` only inspects a parameter or a pattern-bound variable, never a computed value. `match f(x):` is rejected; pass it to a helper.
- `@unsafe def` skips the termination check and falls outside proof guarantees. Server loops either count down a `Nat` fuel argument or are `@unsafe`.
- Tail calls compile to loops.

### Parallelism

```python
def pow2(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      a b = pow2(p) pow2(p)   # parallel let
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(pow2!(20n)))   # `!` runs on the GPU
```

- The parallel let `a b = f(x) g(y)` promises the calls are independent (always true, since pure and affine) and take roughly equal time (the programmer's job).
- The scheduler is a contention-free binary fork-join machine: each task is handed to a core once and never moved. No work stealing. Unbalanced forks lose speedup silently.
- `f!(x)` marks a GPU call; every parallel call inside it runs on the GPU. A machine without a GPU runs `!` on the CPU, still in parallel. The heap is unified, so on Apple silicon moving data to the GPU is free.
- The GPU wins on uniform numeric work (mandelbrot, n-body); divergent work (n-queens, lexer) stays faster on the CPU.
- The JS target ignores all of this and runs sequentially.
- Open question: issue #767 (closed the same day) claimed plain calls do not parallelize on the CPU and only `!` engages the scheduler, contradicting the guide. My binaries were built from programs with `!` marks and scaled fine with `--gpu off`; I did not test a program without any `!`.

### Arrays

```python
def main() -> Array<U32> & U32:
  a = [0 : U32*8n]   # 8 slots of 0; slot count is a power of two; [0 : U32^3n] names the depth
  a[5] <- 42         # in-place write; rebinds a
  a[5]               # read: returns the array beside the element
```

- `Array<T>` is a `Type` with exactly one owner, which is what makes in-place mutation pure. Reads hand the array back next to the element. Indexes wrap.
- The `a[i]` sugar assumes `Array<U32>`; other element types use `Array.get` (Data elements) or `Array.swap`, `Array.set`, `Array.clone`. Taelin conceded on HN that exposing the "array beside the element" read was a mistake he will redesign.
- Internally an array is a perfect binary tree; the backends store machine-word arrays as one flat block of packed 32-bit cells.

### Quantities and kinds

```python
# -A: erased, n: affine, +x: reusable (requires A to be Data)
def replicate(-A: Data, n: Nat, +x: A) -> List<A>:
  ...

# a: a quantity (&0, &1 or &2); -A: a type whose values may be used a times
def length(a, -A: Kind(a), xs: List<a, A>) -> Nat:
  ...
length(&2, U32, [1, 2, 3])
```

- Every type has a kind capping how often its values may be used. `Type` = `Kind(&1)` (linear, non-copiable), `Data` = `Kind(&2)` (copiable). Taelin likened `Kind(&0)` to Rocq's Prop.
- Base declares `type List<a, -A: Kind(a)> is Kind(a)`: a list is exactly as reusable as its elements. `List<U32>` is `List<&1, U32>`; `+List<U32>` is `List<&2, U32>`. Two element types combine with `a <&> b`, the minimum.
- Taelin called the bare quantity parameter (`a` playing the role of a Rust `Copy` bound) confusing syntax he intends to improve.

### Templates

```python
def twice(~f: U32 -> U32, x: U32) -> U32:
  f(f(x))

twice(~(x => (x + 1 : U32)), 40)
```

A `~` parameter is substituted at compile time. Its argument must be closed (top-level defs only, no caller locals). Each distinct set of `~` arguments compiles to its own copy, so the "function" can be called freely, unlike a closure. Template parameters come first and may only call templates declared above them. This is how `List.map` is written, and how the netcode demo compiles its replay fold per game.

### Laws and proofs

```python
law add_zero:
  for x: Nat
  {Nat.add(x, 0n) == x : Nat}

def add_zero(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}
```

- A `law` is a claim; a `def` of the same name proves it. A law with no def is an open claim (an axiom for dead code; live code may not consume it).
- `{a == b : T}` is an equality type; `{==}` proves it when both sides compute to the same term. Matching refines the goal per case; a recursive call is the induction hypothesis; `%e : P` rewrites with `e : {a == b : T}` where `P` is the goal with `_` marking `b`. `%e@E : P` names the equation.
- `for x: A` quantifies; `for y: B where P(y)` packs a hypothesis; `exs z: C` demands a witness, returned as `(z, proof)`.
- `?name` prints the goal; `?TODO` leaves it open (the hub rejects files with open TODOs or unfilled laws).
- `{a != b : T}` is `{a == b : T} -> Empty`. A `match e:` with no cases closes a branch where `e : Empty`. Base has `Equal.sym`, `Equal.trans`, `Equal.cong`.
- No tactics, no proof search. Types are terms, so `def IsEven(n: Nat) -> Type:` is how dependent types are written.
- Convention: `LAWS.bend` imports the code and states laws (the human's file); `PROOF.bend` imports `LAWS.bend` and fills each law as `def Laws.name(...)` (the AI's file). `bend PROOF.bend` prints "All terms check." when every law holds.
- Bug filed on launch day (#776): `bend PROOF.bend` exits 0 when `@unsafe` appears anywhere in the import graph and only checks the laws it can see.

### IO, concurrency, monads

```python
def main() -> IO(Unit):
  do IO<Unit>:
    name : String <- IO.try(String, IO.get_env("USER"))
    chan : Chan(String) <- IO.fork(String, greet(name))
    IO.print("Waiting...")
    text : String <- IO.join(String, chan)
    IO.print(text)
```

- Every bind is annotated. `x : T = v` binds a pure value inside a block. `return e` wraps a pure value.
- Fallible effects answer `Result<&1, &1, U32 & String, A>`; `IO.try` unwraps or exits with the error; `IO.die` exits with your own.
- Handles (`File`, `Socket`, `Listener`, `Window`, `Audio`) are affine opaque values declared as laws with no constructors; every effect hands the handle back beside its result. `Chan` is `Data`.
- One event loop, Node-style: each computation runs pure code (in parallel, on every core) up to its next effect, then yields. `IO.fork` / `IO.join` over `IO.spawn`, `Chan.new`, `Chan.send`, `Chan.recv`, `Chan.close`. Deadlock is reported when all remaining computations wait.
- Effects shipped: print, print_err, get_env, now, sleep, spawn, channels, files (open, read, read_bytes, write, close), TCP (listen, accept, connect, send, recv, close), UDP (bind, send_to, recv_from, poll), window (open, frame, set_title, close), audio (open, write, close). No TLS, HTTP library, JSON, or regex.
- Foreign effects: a def whose body is `import "./x.c"` plus `import "./x.js"`, implemented by a host function named after the def (lowercased, dots to underscores). Only the event loop runs host code, so proofs and the GPU never touch it.
- JS interop: `import Game from "./game.bend"` works under bun (plugin) and node (`--import`) with `bend2/main.ts` preloaded. Constructors become `{$: "Name", field: value}`, `Nat` becomes `BigInt`, Bool/String/U32 are native.
- `do M<xs.., R>:` works for any type with `M.bind` and `M.pure`: `IO`, `Maybe`, `Result`, or your own.

### Apps and graphics

- A frame is an `Image`: `Pix{color}` paints a square, `Qua{tl, tr, bl, br}` splits in four (a quadtree), so frames are drawn by recursion, in parallel if wanted.
- `App.run(~S, ~App{view, tick}, title, w, h, init)` opens a window and calls `view` then `tick` per frame until `tick` answers `None`. Events: `Key`, `Mouse`, `Move`, `Close`. The state is affine, so `view` returns it beside the image.
- Demos include a pong game, a 3D ray tracer, and "Slash Boss 3D", a 3,220-line duel game over a 1,553-line `bend3d.bend` library that mixes its own audio. Taelin posted on 2026-09-10 that an agent ("Astra") wrote an entire 3D engine overnight in Bend 2 running at 120 FPS.

### Modules and packages

- A module is a file; `import ./math.bend as M` gives it a local alias. Dots inside names are just characters (`U32.show` needs no module).
- A law left open in one file can be filled in another as `def M.name(..)`, so proofs can ship separately from claims.
- `import 0x<hash>/main.bend as P` imports from the hub by content hash, checked against the hash, cached in `~/.bend/lib`. `bend main.bend --publish` uploads a file with all its imports after a proof of work (140,000,000 sha256 hashes per 256 KiB, "two seconds of an M4 Max's sixteen cores") and prints the import line. No names, versions, accounts, or search.

### Syntax reference (verbatim from GUIDE.md)

```python
# Top level
import Base                              # the prelude
import ./file.bend as M                  # a module; its defs are M.x
type D<a, -A: Kind(a)> is Kind(a):       # a datatype and its kind
  K{x: A, xs: List<a, A>}                # one constructor per line
def f(x: A, -y: B, +z: C) -> T:          # a def; the body follows
def f(x, y):                             # fills the law named f
def t(~g: A -> B, x: A) -> B:            # a template
law f:                                   # a claim, proven by def f
  for x: A                               # a parameter (also for -x, for +x)
  for y: B where P(y)                    # y is then the pair (y, P(y) proof)
  exs z: C                               # a witness the proof must return
  T                                      # the claim
@unsafe def f(x: A) -> T:                # skips the termination check
def e(x: A) -> IO(B):                    # a foreign effect
  import "./e.c"
  import "./e.js"

# Types
Type  Data  Kind(q)                      # kinds; Type = Kind(&1), Data = Kind(&2)
Quant  &0  &1  &2  a <&> b               # quantities and their minimum
A -> B  @x:A -> B  @-x:A -> B            # functions: plain, dependent, erased
A & B  &x:A -> B  A | B                  # pairs, dependent pairs, sums
D<A>  +D<A>  D<&2, A>                    # a datatype; + makes it reusable
{a == b : T}  {a != b : T}               # equality and its negation

# Terms
42  1.5  3n  'c'  "s"                    # U32, F32, Nat, Char, String
[a, b]  h <> t  (a, b)                   # a list, a cons, a tuple
K{a, b}  x => e  +x => e                 # a constructor, a lambda
f(a, b)  f!(a)  t(~g, a)                 # a call, on the GPU, of a template
(a + b * c : T)  {x : T}                 # operators over T; an annotation
[v : T*n]  [v : T^d]  a[i]  a[i] <- v    # an array of n or 2^d slots; a read, a write
{==}  %e : P; e2  %e@E : P; e2           # reflexivity, a rewrite, a named one
?name  ?TODO                             # print the goal; leave it open

# Statements
x = v  +x = v  -x = v                    # a let: affine, reusable, erased
(a, b) = v  K{x, y} = v                  # a destructuring let
a b = f(x) g(y)                          # a parallel let
match a b:                               # a match on one or more values
  case K{x, _} 1n+p:                     # patterns nest; _ catches the rest
do M<xs.., R>:                           # a monadic block over M.bind, M.pure
  x : A <- m                             # bind
  x : A = v                              # let
  m                                      # a Unit step
  return v                               # the result
```

Reserved words: def, type, law, match, case, do, return, for, exs, where, is, import, Type, Data, Kind, Quant. Inside `(.. : T)`: `+ - * / %` call `T.add` .. `T.mod`, `.&. .|. .^.` the bit ops, `<< >>` shifts by a `Nat`, `< <= > >=` the `T.is_lt` family. `&& ||` on Bool and `++` on String work anywhere.

### Base library

- 22 types: Empty, Unit, Bool (False/True), Cmp (LT/EQ/GT), Either, Sigma, Nat (Zero/Succ), Maybe, Result (Fail/Done), List (Nil/Con), Word.Nil, Word.Con, U32 (a 32-bit Word), F32, Char, String (SNil/SCon, a linked list), Array (ALeaf/ANode), Image (Pix/Qua), Event, Map (MTip/MLeaf/MNode, string keys: new set get has del keys), IO.OP (Emit/Halt), App.
- Naming scheme `Type.verb`: add sub mul div mod; and or xor not shl shr (U32 only); cmp (not on F32); is_eq is_ne is_lt is_le is_gt is_ge; show and read; T.to_x and T.from_x. `Set` sits on `Map`.
- `bend base` prints all of it, `bend base --types` the types, `bend base Map` one name and its subnames.
- Small by admission. An HN user's agent reported Base ships one arithmetic law (`U32.add_comm`) and no order theory, so ~60 of 163 proof lines were basic lemmas; Taelin replied "we need a mathlib!". `Nat.max` is defined via a computed pick, which a proof cannot case on. [S, from the HN thread]

## Type theory (BendTT paper, 5 pages)

- One sort with `Type : Type`, impredicative quantification, and datatypes with no positivity restriction (negative recursive types like a HOAS `Trm` are legal), yet claimed consistent.
- Mechanism: a usage discipline instead of a universe hierarchy. A value is consumed at most once unless the kind of its type says otherwise. A `+` binder forms only at kind `Data`; a function type is never `Data`; a datatype earns `Data` at every constructor. So a live function is never copied, and every classical paradox (Girard, Hurkens, Curry) copies a closure and dies at the usage counter.
- Two checking demands: live (code that runs) and dead (types, erased arguments, equations). Dead code is free, may diverge, may inhabit Empty, but never counts as live evidence. Live recursion passes one syntactic descent test (lexicographic, left to right, strict subterm from the definition's own case tree).
- One bidirectional pass, a usage counter per binder, no unification, no tactics. The match is the eliminator (dependent, with the constructor peeled onto the family). Equality is the J axiom with an explicit motive (the `%` rewrite).
- Claims: subject reduction, progress, weak normalization of closed live terms, no closed live inhabitant of Empty. Stated for the live fragment; dead code is specification, not proof. Consistency result is syntactic and relative to Lean; equality is intensional.
- Lean 4 mechanization: about 21k lines, no `sorry`, no axioms; proves church_rosser, subject_reduction, progress, normalization, consistency for a de Bruijn model of the core. The file header and paper both say the model does not yet match the shipped checker; "independent audits are needed".
- Related work cited: QTT (Atkey; Brady's Idris 2, which Taelin names as an inspiration), graded types, LLF, Lean4Lean. The paper's AI disclosure: "designed by the human author ... written by Claude Fable 5.1 from the author's code and design choices, and reviewed by the author."

## Runtime (BendRT paper, 6 pages)

- One C file per program; the same file is the CPU program and the GPU kernel (Metal or CUDA selected by macros). Compiled with `clang -std=c11 -O3`; on macOS as Objective-C with `-fmodules` for Metal; CUDA via `-DBEND_CUDA=1` and nvrtc at runtime.
- Term = one 64-bit word: tag, 16-bit aux, 40-bit heap location. Machine words, small `Nat`s, and one-field constructors are packed inline. One heap shared by every core and the GPU; the host reserves 8 TB of virtual memory and pages fault on touch; the GPU span is fixed before the first dispatch (`--gpu 4GB`, default 2 GB on Metal, whole card on CUDA).
- No garbage collector: affinity means a match frees the node it opens; only `+` values carry a reference count, placed by whole-program "share inference" and "borrow inference". Drop is an iterative walk.
- No C stack: each def is a segment of a flat state machine, a call is a jump (host: `preserve_none` functions with `musttail`; device: one switch in an error-polling loop). Value stack per host worker is a guarded 2 GB mapping.
- Scheduling: the "task cube", 2^14 rings in a 128 x 128 square, each ring a fixed FIFO of 1024 slots. Bulk-synchronous rhythm: grow phases fork along rows, work phases drain along columns, the cube flips between them. No shared deque, no locks, no migration, no rebalancing. Host pool up to 128 threads; GPU grow runs as 128 threadgroups.
- Contract: forks must be balanced. A skewed program silently loses its parallelism. The CPU and GPU never compute at the same time; a `!` is honored only at a sequential point on the event loop.
- Failure is a numbered fail-stop: ring holds 1024 tasks, count saturates at 2^24, `Nat` at 2^48, block depth 31.
- Floats: contraction off, same semantics on every executor, and the harness checks all three Bend lanes print identical bytes.
- JS backend: one function per def, constructors as tagged objects, tail calls trampolined, forks run in sequence.
- CUDA lane is in the source but the paper says it is unverified and not measured; Metal is what was measured.
- Interaction nets: "Readers of the author's earlier runtimes may expect interaction nets here; there are none." Lost: optimal reduction of shared redexes. Gained: native-speed sequential code, flat memory, a readable cost model.

## Tooling, install, telemetry

CLI (from `main.ts`):

```
bend <file.bend>            check the file, then run main
bend <file.bend> -o <out>   build a binary; <out>.c emits C, <out>.js JS
bend <file.bend> --checkup  check and run each import alone
bend <file.bend> --publish  publish the file and its imports to the hub
bend <page.html> -o <dir>   bundle a page that imports .bend files
bend base [--types|<name>]  print Base, its types, or a name and its subnames
bend guide                  print the Bend guide
bend --version              print the version
```

Binary flags: `--threads N` (1 to 128, default CPU count), `--gpu on|off|4GB` (default on if a GPU is present, over 2 GB on Metal), `--gpu-build` (write the GPU program and exit). A binary using `!` ships a `<name>.gpu` file beside it that must stay there; it is compiled at first launch and cached.

Requirements: clang 14+ for a binary, clang 19+ when `!` is used, Metal on macOS or CUDA 12 at `/usr/local/cuda` on Linux (PR #771 adds `$CUDA_HOME`). Linux windows need `libx11-dev`, audio needs `libasound2-dev`. No Windows (WSL works). Native compiles are slow; JS is for fast iteration.

Installer (`curl -fsSL https://bend-lang.com/install.sh | sh`), read in full:

- Installs Bun if missing (via bun.sh), writes a launcher to `~/.bend/bin/bend` (override with `BEND_HOME`), appends a PATH export to your shell rc, fetches the current release tarball, verifies sha256, extracts to `~/.bend/app/<ver>`, symlinks `current`.
- The launcher runs `bun ~/.bend/current/bend2/main.ts "$@"`. So `bend` is a TypeScript program running under Bun, not a native binary.
- Telemetry: every run POSTs `{id, ver, os, arch, cmd, exit, ms}` to `https://bend-lang.com/ping` in the background and self-updates when the reply names a new version. Opt out with `BEND_NO_TELEMETRY=1`; `BEND_ORIGIN` overrides the server. The installer prints a one-line disclosure.
- Alternative with no install: clone the repo and run `bun bend2/main.ts <file.bend>` directly. This is what I did. [V]

Ecosystem:

- BendHub: content-addressed, trust-free, no accounts; publishing needs proof of work; files with `?TODO` or unfilled laws are rejected. Launch-day issues #768, #787, #788, #794 cover path traversal and unverified manifest entries in the hub client.
- Bender: "the proving agent for Bend", proves and fixes `PROOF.bend` when code changes; today "a thin harness around models from Anthropic, OpenAI and others"; specialized models and SupGen (a symbolic prover) promised later; sold as credits worth one dollar each, valid twelve months, "founder price: 50% off". [R, via fetched summary of the page]
- Missing: debugger, profiler, formatter, REPL, LSP, editor support, test framework. An LSP and a tree-sitter grammar existed for Bend 1 (archived 2024-10).

## Demos (each with LAWS.bend and PROOF.bend)

| demo | what it shows |
|---|---|
| app_win_is_bug_2d | the launch demo: a torus-map game with law `you_cant_win` over any move sequence; a 484-line AI-written proof by invariant ("player on a safe cell"), with the finite geometry checked by evaluating `chk_all` to True; playable at bend-lang.com/#lab |
| app_pong_game_2d, app_triangle_2d, app_ray_tracer_3d | windowed apps over `App.run` |
| app_slash_boss_3d | 3,220-line 3D duel game plus 1,553-line bend3d library; laws: pause freezes the world, P twice restores pause state, Esc quits |
| io_hello_world, io_tcp_echos, io_http_fetch, io_http_server | effects; the HTTP server's laws: response = head ++ "\r\n\r\n" ++ page (with an `exs` witness), and response injectivity; its accept loop is `@unsafe` |
| io_rollback_netcode | 917-line input-synced rollback netcode library over UDP with a relay server and a headless two-bot test |
| proof_insertion_sort | laws `sort_sorted` and `sort_perm` (permutation stated by counts) |
| proof_numerics, proof_typed_eval | pure proofs |
| pure_par_sum, pure_par_sort | fork/join with a law that the tree equals the sequential spec |
| pure_hvm5_mini | 1,916 lines: HVM reimplemented in Bend, with laws about its lexer, parser cursor, and printer. Taelin on HN: "HVM has been reimplemented in Bend 2 ... Don't tell anyone though!" |

`@unsafe` appears in 3 demo files (http server, netcode, walkers_demo) and nowhere in Base. No `?TODO` in any demo. [V]

## Benchmarks

### Repo pins, Apple M4 Max, runtime (2026-09-17, commit d0db7b3e), seconds, plus peak memory

| bench | SEQ-CPU (1 thread) | PAR-CPU (16 threads) | PAR-GPU (Metal) | C | TS | Lean |
|---|---|---|---|---|---|---|
| bfs | 3.918 | 0.343 | 0.207 | 3.585 | 6.534 | 9.274 |
| editdist | 2.559 | 0.236 | 0.144 | 2.002 | 5.290 | 4.799 |
| gameoflife | 7.803 | 0.647 | 0.063 | 6.776 | 18.754 | 13.849 |
| hashmap | 2.741 | 0.238 | 0.521 | 0.622 | 0.892 | 1.526 |
| kmeans | 2.069 | 0.268 | 0.191 | 2.062 | 17.455 | 5.686 |
| lexer | 2.144 | 0.198 | 1.075 | 1.036 | 3.543 | 4.487 |
| mandelbrot | 4.473 | 0.395 | 0.057 | 3.750 | 3.837 | 4.575 |
| merkle | 4.222 | 0.422 | 0.071 | 3.423 | 7.227 | 5.986 |
| nbody | 5.758 | 0.516 | 0.059 | 5.126 | 5.332 | 5.387 |
| queens | 5.406 | 0.455 | 0.933 | 3.599 | 6.979 | 7.704 |
| raytrace | 4.616 | 0.396 | 0.151 | 3.646 | 23.039 | 10.825 |
| symreg | 3.014 | 0.266 | 0.529 | 2.208 | 5.924 | 2.457 |
| terrain | 2.225 | 0.197 | 0.106 | 2.198 | 5.746 | 8.039 |
| tree-bitonic | 6.043 | 0.799 | 0.450 | 5.719 | 33.910 | 38.123 |
| tree-matmul | 2.064 | 0.226 | 0.231 | 2.964 | 11.379 | 7.758 |
| tree-radix | 4.083 | 0.445 | 0.314 | 2.791 | 6.244 | 6.500 |

Reading: single thread within roughly 0.8x to 1.5x of the hand-written C twin (hashmap is the outlier at 4.4x slower, lexer 2x); 16 threads give 9x to 12x; the GPU gives 50x to 75x on uniform work (mandelbrot, nbody, gameoflife, merkle) but is slower than 16 CPU threads on divergent work (lexer, hashmap, queens, symreg). All benches carry a `!` mark; the harness runs the lanes with `--threads 1 --gpu off`, `--threads N --gpu off`, and `--gpu <mem>`. Twins are built with `cc -std=c11 -O3`. The landing page's chart rows are generated from these pins by `gen_charts.ts`. On the base M4 pin the compiler itself takes 0.55 s to 1.5 s per bench. [R]

### Repo pins, checker (2026-09-09, commit f655a39d), seconds; ">300" is a five-minute timeout

| bench | Isabelle | Agda | Lean | Rocq | Bend |
|---|---|---|---|---|---|
| defs_12800 (12,800 definitions) | >300 | >300 | 36.177 | 5.985 | 0.295 |
| generics_3200 (3,200 generic instantiations) | >300 | >300 | 19.214 | 6.038 | 0.384 |
| proofs_3200 (3,200 proofs) | >300 | >300 | >300 | 9.526 | 0.834 |
| trees_400 (400 smalltt trees) | 8.475 | 3.266 | 1.335 | 1.339 | 0.606 |

The synthetic files favor a checker with zero inference, unification, or search; on the one realistic-looking bench (smalltt trees) the gap to Lean and Rocq is about 2x. Taelin's framing on HN: anyone building Lean or Agda "would agree these would be much faster with zero inference, unification or search"; the cost is ergonomics and verbosity. HN critics (stschaef) said the comparisons are meaningless without knowing what is compared and asked for a real port of a verified codebase. [R]

### My measurements, 2026-09-17 [V]

Machine: Apple M5 Pro, 18 cores, macOS (Darwin 25.6.0), Apple clang 21.0.0, Bun 1.4.2. `xcrun --find metal` fails on this machine, yet the Metal lane works because the runtime compiles the device program through the Metal framework at launch and caches it as `<binary>.gpu`. C twins built with `clang -O3 -std=c11 -lm`.

| program | Bend 1 thread | Bend 18 threads | Bend GPU (Metal) | C twin |
|---|---|---|---|---|
| nbody | 8.27 s | 0.49 s (16.9x) | 0.17 s (48.6x) | 7.57 s |
| gameoflife | 11.26 s | 0.95 s (11.9x) | 0.15 s (75x) | 9.73 s |

- Bend single-thread is 1.09x (nbody) and 1.16x (gameoflife) slower than C here. Every lane, including the C twin, was slower than the M4 Max pins by 30% to 50%, so this machine or its power state was slower; relative numbers are what matter.
- Checksums: gameoflife printed 2016151040 on all three Bend lanes and from the C twin, matching the pinned OUTPUT. nbody printed 3516450380 on all Bend lanes (matches the pin) but the C twin printed 1424365735. Not investigated; the paper only promises identical bytes across the Bend lanes.
- Compile times: nbody 3.2 s wall for `bend -o` including clang; pure_par_sum 1.1 s.
- Checker: `demos/pure_par_sum/PROOF.bend` 0.075 s wall, `demos/app_win_is_bug_2d/PROOF.bend` 0.55 s wall, both "All terms check."
- JS backend: hello world 0.076 s wall; `sum!(16n, 0n)` printed 2147450880 in 0.084 s.
- Gotcha I hit: with a GPU present a binary defaults to `--gpu on`, so timing a `!` program without `--gpu off` measures the GPU lane.

## Limitations (README, verbatim list)

```
- Bend 2 is a new language. Bend 1 programs and HVM do not carry over.
- Everything is annotated and nothing is inferred, so code is verbose.
- No type classes, no traits, and no macros beyond compile-time templates.
- Bend has no tactics or proof search; proving theorems takes extra effort.
- Values are affine: closures and arrays cannot be shared.
- Recursion must be terminating. (Use `@unsafe` to disable this checker.)
- Computed matches (`match f(x)`) aren't supported. Must split it manually.
- There is no syntax for if-then-else: a branch is a match on True and False.
- Numbers are Nat, U32 and F32 only: no U64, I64 or F64 (Metal has no f64).
- F32 is axiomatic: nothing about floating point can be proven.
- Strings are linked lists of characters, so text processing is slow.
- Base is small: expect to write helpers other languages ship built in.
- Effects are few: print, env, time, sleep, spawn, channels, files, TCP, UDP.
- No TLS, HTTP library, JSON or regex for now (but you can add them as foreigns).
- Targets are C, Metal, CUDA and JavaScript; Lua, Luau and Python are planned.
- The JavaScript target runs on one core and has no graphics or audio.
- Parallelism requires balanced calls. Flexible parallelism will be added later.
- Sharing arrays with atomics across threads is experimental and needs `@unsafe`.
- One GPU per program, one event loop, and no multi-machine execution yet.
- One C file per program: no separate compilation, no incremental builds.
- Compiling to native is slow (clang/CUDA/Metal). For fast development, use JS.
- The compiler is young and has blind spots (unusually slow programs). Report.
- We don't have as many benchmarks as we'd like yet, especially for the checker.
- The compiler (not kernel) is 99% AI-written and has not been fully audited yet.
- The Lean formalization and bend.ts mismatch. Early consistency bugs may occur.
- A binary needs clang 14+; ! needs 19+, Metal or CUDA 12.
- No Windows (WSL works); on Linux, Window and Audio need X11 and ALSA headers.
- The hub has no names, versions, accounts or search yet. Packages are hashes.
- Error messages are terse; no debugger, profiler, formatter, REPL or LSP.
- No editor support, no test framework and no documentation beyond the guide.
```

A PR adding F64 (#795) was open on launch night.

### Launch-day issues (2026-09-17/18)

#776 `bend PROOF.bend` exits 0 with `@unsafe` in the import graph and checks only visible laws; #775 unused argument evaluated natively but skipped by the JS runner; #779/#791 checker stack overflow on large `Nat` literals (about 10k deep); #784 template argument that is a plain def parameter fails; #785 compiler quadratic in the number of sequential statements; #789 C build "unbound name in the emitted C" for some printed types; #790 JS backend silently merges defs whose names mangle to the same identifier; #792 IO receive effects eagerly allocate the caller-supplied max and abort; #793 bend.ts accepts books the Lean kernel refuses (base-file live calls to later-filled laws); #768/#787/#788/#794 hub client path traversal, unverified manifest lines, partial installs. Closed same day: #767 (plain calls not parallelizing on CPU), #769 (Homebrew clang and `-fmodules`), #773 (Arch Linux C build), #774 (Android mmap size).

## History and lineage

| when | event | evidence |
|---|---|---|
| 2022-01 | HVM1: "a massively parallel, optimal functional runtime in Rust" by Victor Taelin; interaction combinators; 11,339 stars today; `hvm` crate has 219k downloads, last release 2.0.22 on 2024-08-09 | R |
| 2023 | Higher Order Company raises a seed round. Taelin, Jan 2024: "$4m seed round ... hired a team of ~10 highly talented engineers, giving us a ~3 year runway". Third-party pages say $4.5M | S |
| 2024-05-16 | Bend 1 "RELEASE DAY ... After almost 10 years of hard work" on HVM2. HN thread reaches 1,041 points and 253 comments | R |
| 2024-05 to 2025-02 | Bend 1 releases 0.2.3 through 0.2.38 on crates.io (33,759 downloads); bend-language-server and tree-sitter-bend archived 2024-10 | R |
| 2024-11-14 | HVM3 (Haskell + C): "up to 2400 MIPS single-core (WIP) ... up to 42x faster than Bend (since it is interpreted), and 2x-3x faster than Node.js and Haskell, in a single thread" | R |
| 2025-01 | Kind (the company's proof language, Haskell rewrite) last pushed; kind2-archive and Kind2-old in the archive org | R |
| 2025-06-18 | Wefunder community round: pitched as $4M at a $60M valuation to "complete the language, integrate LLMs, build dev tools (LSP, editor, docs), and grow adoption" [S]; Taelin caps it at $1.5M: "raising 4m will be laborious (I guess trust in us is at an all time low)" | R for the cap |
| 2025-07 | Bend2 exists as a Haskell WIP (a fork shows 196 KB of Haskell); later archived as `HigherOrderCO-archive/Bend2-old`, now 404 | R |
| 2025-08-19 | "To recap everything about Bend2: NeoGen is a 'program miner' that exploits HVM's optimality ... still exponential, but with a constant speedup large enough to find certain programs that were previously intractable". Search excerpts add "up to 10,000x faster than Myth" | R / S |
| 2025-11-03 | "HVM4 now includes a general method to compile Interaction Calculus functions to zero-overhead machine code, including functions with superpositions"; same day a state-of-HOC thread lists Bend1's problems starting with interpretation overhead | R (truncated) |
| 2026-02-16 | Branding thread: Bend2 "built from scratch around the idea that we, humans, will stop maintaining codebases. Instead, we write specs - i.e., what we want, as precise types - and the AI..." | R (truncated) |
| 2026-03-05 | Pre-launch list: "1. HVM4's AOT compiler ... gives a 10x-100x speedup in practice, so, it is essential" | R (truncated) |
| 2026-05-30 | Last HVM4 commit ("collapse: general filter-credit scheduler"); HVM4 README still says "you're here before launch" | R |
| 2026-08-31 | BendRT paper's pin date (commit 64fc4b7, which no longer exists publicly) | R |
| 2026-09-10 | Taelin: an agent built a full 3D game engine overnight in Bend2 | R |
| 2026-09-17 | Bend 2.0.5 launches in TypeScript with its own runtime; no HVM. HN: 259 points, 133 comments by late evening | R |

Why HVM was dropped: Taelin on HN, asked directly, said "It didn't 'need to', it just evolves by rewrites as I learn (the project is fairly small) so in the latest rewrite I choose Bend!" The BendRT paper states the design tradeoff (affinity gives unique ownership directly, so the interaction-net duplication machinery is unnecessary; optimal sharing is lost, native-speed sequential code is gained). The shift from a Haskell Bend2 on HVM3/HVM4 to a TypeScript Bend2 with a bespoke runtime happened between March and September 2026 and is not narrated anywhere I could read.

### Bend 1 in brief (for context)

- Rust implementation, HVM2 backend (interaction combinators), Apache 2.0. Install was `cargo install hvm` then `cargo install bend-lang`; needed GCC 12.x or earlier and CUDA 12.x for `run-cu`. [R]
- Commands: `bend run` (C interpreter, parallel, default), `bend run-rs` (Rust, sequential), `bend run-c`, `bend run-cu` (CUDA); `-s` printed reductions, time, interactions per second. [R]
- Numeric types `u24`, `i24`, `f24` only; `switch` on numbers, `match` on ADTs, `fold` to consume recursive types, `bend` to build them; strings were lists of `u24`. [R]
- Headline benchmark: a bitonic sorter at 12.15 s (Rust, sequential, M3 Max), 0.96 s (C, parallel, M3 Max), 0.21 s (CUDA, RTX 4090). [R]
- Two surface syntaxes, "Imp" (Python-like) and "Fun" (Haskell-like). [M]
- 2024 HN reception: praise for closures and unrestricted recursion on GPUs; criticism that a Python port beat it (PyPy 4.5 s vs Bend 42+ minutes on an i7, which Taelin called a bug), that C++ at -O3 did the sum in about 80 ms vs Bend's 1.88 s on an RTX 4090, and that 24-bit numbers were arbitrary. Taelin: "The only claim I made is that it scales linearly with cores. Nothing else!"; "Bend has no tail-call optimization yet"; "a single GPU core is 100x weaker than a CPU core". [R]
- Bend 1 users have no migration path; the old repo is kept at HigherOrderCO/Bend1 (a HOC developer suggested on HN it could become a branch).

### HVM lineage

- HVM1 (2022, Rust): optimal functional runtime on interaction combinators.
- HVM2 (2024, Rust): the strict interaction-net runtime under Bend 1; `hvm run|run-c|run-cu|gen-c|gen-cu`; "not meant for direct human usage".
- HVM3 (2024-25, Haskell + C): Interaction Calculus with affine lambdas without scope boundaries, first-class duplications and superpositions, optimal beta reduction; `hvm run file.hvml -c` compiles to C. "Aims to be the main compile target of Bend."
- HVM4 (2025-26, C): "a high-performance runtime for the Interaction Calculus"; `-C10` collapses superpositions; superposition syntax `&{1, 2}`; docs on theory, core, memory layout, interaction rules; pre-launch.
- NeoGen / SupGen: program synthesis from specs by enumerating superposed programs on HVM. SupGen is proprietary (Taelin: the squashed history held "proprietary code (like SupGen)"). Bender promises SupGen as a future prover.
- None of this ships in Bend 2. The HVM lineage lives on only as the `pure_hvm5_mini` demo written in Bend.

## Company and people

- Higher Order Company (HOC), Rio de Janeiro, Brazil. Founder Victor Taelin (Reddit: SrPeixinho; HN: LightMachine; X: @VictorTaelin), earlier author of Formality, Kind, Kindelia, HVM. [R]
- Taelin on launch day: "I've worked on this for 1 year, nearly 16h/day, 7 days a week, and I'm giving it for free." "We're a small team." The repo's only commit is his. Both papers and most of the compiler are AI-written from his designs; the kernel `bend.ts` is "99% human-designed and audited". [R]
- Revenue plan visible so far: Bender credits; the Bender page says credits may later cover cloud compute and feature voting. [R]
- Funding: 2023 seed ($4M per Taelin, $4.5M per third parties), 2025 community round capped at $1.5M. Wefunder page and bend2.dev were unreachable from this sandbox, so their details are search excerpts only. [S]

## Reception, launch day (HN 49746163, 259 points, 133 comments)

Praise: the idea of a language designed from the start to be proved; the GPU runtime; Taelin's candor; people who tried to break the demo law ("jump over walls", "teleport the flag", "make the world 3D") reported being blocked.

Criticism and Taelin's replies:

- Under-specification. pdpi asked the AI to remove the walls; it preserved "you can't win" by switching to diagonal movement. Taelin: "'you can't win' is grossly under-specified ... laws only protect what you remember to write. They're not a silver bullet." He argued one law ("the sum of all balances in this contract must be zero") would have prevented The DAO hack.
- Laws drift. RomanKornev: agents edit the law to fit the feature. Taelin: "you want to at least read what the AI is putting on LAWS.bend ... astronomically less code. Not zero code."
- Trust signals. Single squashed commit, 20k inherited stars ("about the same as Crystal and Gleam", ModernMech), benchmark SHAs in the paper that no longer resolve, AI-written papers ("If the ideas are yours then it should be feasible to write the paper", stschaef). Taelin: the history had "a lot of personal info and AI slop" and proprietary SupGen code; "we could try to restore history removing sensitive bits".
- Compiler quality. Taelin: comp.ts "is not a pretty file and it has a lot of gambiarra and AI slop for now"; read bend.ts instead.
- Novelty. Taelin: "I don't think it is worthy publication because the core idea is simple. We just use QTT-like linear types to fully prohibit runtime closures ... In exchange, functions like List.map are not expressive (without templates)."
- Practicality. svachalek ported a small cron job with Claude Opus 5; it worked but most of the proof file was basic lemmas Base lacks. Taelin: "we need a mathlib!"
- Design regrets admitted: the `arr[i]` read returning the array beside the element; the bare quantity parameter syntax; possible non-termination to be addressed "via codata / coroutines" in later versions.
- Other: no Windows; F32 axiomatic; "post-AGI" framing mocked; comparisons to Ada/SPARK, Dafny, Idris 2 requested; scheduler is "very simple (for now) ... you must still tune it manually"; parallelism confirmed on multi-core CPUs, Apple M-series GPUs, and NVIDIA.

## Relevance to a quantum simulator (my assessment)

- Numerics: `F32` only, axiomatic (no proofs about floats), no `F64`, no complex type, no SIMD control. A state-vector simulator would need complex F32 pairs hand-rolled in U32/F32 arrays, and nothing about numerical error could be stated as a law. An F64 PR exists but Metal has no f64 anyway.
- Data: arrays are perfect binary trees with power-of-two sizes and single ownership; the index sugar only covers `Array<U32>`. Amplitude arrays of 2^n fit the shape, but gate application as balanced fork/join over tree halves is the only parallel idiom, and cross-thread shared arrays with atomics are experimental and `@unsafe`.
- Scale: one GPU per program, GPU span fixed at launch (2 GB default on Metal), the CPU and GPU never compute concurrently, no multi-machine execution.
- Where it could fit: proving structural properties of circuits (gate count, qubit bounds, unitary composition over a symbolic algebra) as laws, or a teaching simulator over small `Nat`-indexed states. Not a practical target for a performance simulator today.

## Open questions and things not verified

- Whether plain (non-`!`) calls parallelize on the CPU in native binaries (issue #767, closed same day; not tested).
- Why the nbody C twin's checksum differs from Bend's.
- The full text of Taelin's Nov 2025 and Mar 2026 threads (oembed only returns the first post).
- Wefunder terms and the team size today.
- CUDA lane behavior (unverified per the paper; no NVIDIA hardware here).
- What changed between the Haskell Bend2 prototype and the shipped TypeScript one, and when HVM4 was dropped.

## Sources

- https://bend-lang.com/ and https://bend-lang.com/install.sh and https://bend-lang.com/dl/latest.json
- https://github.com/bendlang/bend (README, AGENTS.md, guide/GUIDE.md, bend2/*, bench/*, demos/*, paper/BendTT.pdf, paper/BendRT.pdf)
- https://github.com/HigherOrderCO (Bend1, HVM1, HVM2, HVM3, HVM4, Kind) and https://github.com/HigherOrderCO-archive
- https://hub.bend-lang.com/ and https://bend-lang.com/bender
- https://news.ycombinator.com/item?id=49746163 (Bend 2 launch, 2026-09-17) and https://news.ycombinator.com/item?id=49746203
- https://news.ycombinator.com/item?id=40390287 (Bend 1 launch, 2024-05)
- https://x.com/VictorTaelin/status/2100681226143092875 (launch), 1985423273304473788 (state of HOC), 1985320306001477783 (HVM4 compiles), 2029567059881857081 (pre-launch list), 2023405334677913720 (branding), 1957775213053022614 (NeoGen recap), 1935328258058342512 (round capped), 1791213162525524076 (Bend 1 release day), 1743751536465903795 (seed recap), 2098007807261892927 (Astra game)
- https://wefunder.com/higher.order.co (unreachable from here; search excerpts only)
- https://crates.io/crates/bend-lang and https://crates.io/crates/hvm
