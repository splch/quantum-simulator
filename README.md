# quantum-simulator

A short, complete quantum circuit simulator in [Bend 2](https://bend-lang.com), with laws. The state is a perfect binary tree of complex `F32` amplitudes indexed by the qubit count at the type level; every gate is one generic tree walk driven by a per-qubit role list (skip, control, target); measurement and sampling are tree folds. Correctness is split three ways: shape and totality by the type checker, nineteen structural laws proven in `PROOF.bend`, and numerics by golden lines and a numpy differential test.

## Run it

Bend 2.0.5 is required. This machine runs it through a `~/bin/bend` wrapper over a pinned clone; the [installer](https://bend-lang.com/install.sh) works too.

```sh
bend main.bend                  # the demos on the JS backend
./test.sh                       # every file with #| lines, then ref.py
bend PROOF.bend                 # All terms check.
uv run ref.py --native          # random circuits against numpy, both lanes
bend main.bend -o sim && ./sim --threads 18
./bench.sh 24:2 sample:24:10000 # native timings, see below
```

The JS backend is for development at 16 qubits or fewer. Native builds need clang.

## Layout

| file | what it holds |
|---|---|
| `amp.bend` | the scalar module: complex `F32` amplitudes, `Gate`, `Gate.apply`, and the named gates H X Y Z S Sdg T Tdg P RX RY RZ U |
| `sim.bend` | the state family `Q(n)`, the role walk `apply` and `mix`, the role builder, `Op` and `run`, `norm2`, `prob1`, `project`, `rescale`, `measure`, `expect_z`, the PRNG, `sums`, `shots`, `sample`, `show`, `show_hist`, `near` |
| `circuits.bend` | gate constructors, `swap`, `each`, `mcz`, Grover's oracle and diffusion, `qft` |
| `main.bend` | demos, each printing a pinned `#|` line |
| `gates.bend` | identities that run every named gate |
| `LAWS.bend`, `PROOF.bend` | the claims and their proofs |
| `ref.py` | the numpy differential test, run with `uv` |
| `test.sh`, `bench.sh`, `bench.bend`, `bench_sample.bend` | the test runner and the native benchmark harness |
| `PLAN.md`, `bend-notes.md`, `research/`, `prototype/` | the design, notes on Bend 2, the API survey and smoke findings, the verified prototypes |

## Design in one screen

- **State.** `Q(n)` is a type-level function: `Q(0n)` is one amplitude, `Q(1n+p)` a pair of `Q(p)`. A value of `Q(n)` has exactly 2^n leaves by construction, and it is linear, so a gate pass frees each node as it is matched and needs no reference counts. The root splits on qubit 0, the left child is qubit 0 = |0>, and amplitudes print root to leaf: `011` means q0=0, q1=1, q2=1 (Cirq order, the reverse of Qiskit's).
- **Gates.** `apply(n, roles, g, q)` walks down the roles: it forks at `Skip`, takes only the |1> branch at `Ctrl`, and at `Targ` hands both halves to `mix`, which zips them down to the leaves and applies the 2x2 matrix there, returning both new subtrees from one pass. Any number of controls, above or below the target, and no index arithmetic anywhere. Role lists are built by `roles(n, t, cs)`, never written by hand.
- **Circuits.** An `Op` is a target, its controls and a gate; `run` folds a list of them. `circuits.bend` has one constructor per gate, `swap` as three CNOTs, and `qft(n)`, whose H and halving controlled phases per qubit give n(n+1)/2 rotations followed by the bit-reversal swaps.
- **Measurement.** `measure(n, k, u, q)` takes the uniform `u` explicitly: it reads the probability of 1 beside the rebuilt state, projects the other branch to zeros, and rescales by 1/sqrt(p). Renormalization happens there and nowhere else, so norm drift stays visible.
- **Sampling.** `sums` turns the state into a probability tree holding, at each node, the fraction of its weight in the |0> half. `shots` routes a list of uniforms down that tree, rescaling each side back into [0, 1) and pruning empty subtrees, so 10,000 shots at 24 qubits cost about three gate passes. The PRNG is xorshift32 with a fixed default seed, so histograms are reproducible and pinned.
- **Scalar boundary.** `sim.bend` uses the scalar only through `C`, `Gate` and a handful of functions in `amp.bend`, so an exact Clifford+T ring can replace the floats behind the same interface.

## What is verified

- **By the checker.** `apply : Q(n) -> Q(n)` cannot change the qubit count or the shape; every function is total by structural recursion; there is no `@unsafe` in the import graph.
- **By proof.** `bend PROOF.bend` prints `All terms check.` for nineteen float-free laws: the empty and all-Skip role lists are identities; a control leaves the |0> subtree untouched; running a concatenation equals running the circuits in turn; the role list has one entry per qubit with Targ at the target and Ctrl or Skip at every other index, above and below the target; projecting twice is projecting once, projecting zeros gives zeros, and the other branch is zeros after a projection; the QFT has n(n+1)/2 rotations and three CNOTs per swap; and a histogram's counts sum to the number of uniforms whichever way each F32 comparison goes. Nothing about floats is claimed: every `F32` primitive is an opaque law, so unitarity and H H = I are not provable here.
- **By golden lines.** Bell, GHZ, Toffoli, a control below its target, T^8 = I with T^7 as the negative control, the GHZ norm, expectation values, collapse under both outcomes, a 4096-shot Bell histogram inside three sigma, a biased histogram, teleportation of RY(0.7)|0> for all four outcome pairs, the QFT of |001>, Grover's probabilities 1/8, 25/32, 121/128, and eleven gate identities. The native binary prints the same lines as the JS lane.
- **By differential test.** `ref.py` draws random 5-qubit circuits over every constructor, including rotations with random angles and Haar-random raw unitaries, and compares all 32 amplitudes with a float64 numpy reference: worst error 9.5e-8 over 20 circuits of 40 gates, 1.5e-7 at 200 gates, against a tolerance of 1e-5. The native lane agreed with the JS lane to the bit.

## Performance

Native, no `!`, layers of H on every qubit (`./bench.sh`), on an M5 Pro with 18 cores and 48 GB. These runs shared the machine with other jobs at a load average of 10 to 15, and the prototype harness rebuilt under the same load ran 9.45 s on one thread at 24 qubits against the 3.52 s the design notes recorded on a quiet machine, so the times below are upper bounds; the memory column is exact.

| qubits | H gates | 1 thread | all cores | peak memory |
|---|---|---|---|---|
| 20 | 100 | 1.9 s | 0.34 s | 34 MB |
| 24 | 48 | 10.4 s | 3.3 s | 514 MB |
| 26 | 52 | 41.5 s | 17.7 s | 2.05 GB |
| 28 | 56 | 142 s | 60 s | 8.19 GB |
| 29 | 29 | | 68 s | 16.4 GB |
| 30 | 30 | | 119 s | 32.8 GB |

- Memory is 32 bytes per amplitude at every size, with no higher peak during a pass.
- The ceiling on this machine is 30 qubits; 31 would need 64 GiB. The runtime reserves 8 TiB of address space and commits pages as it goes, so nothing in it limits the size below physical memory, and none of its fail-stops triggered up to 2^30 leaves.
- Sampling 10,000 shots at 24 qubits: 6.8 s on one thread and 1.75 s on all cores including the 24 preparation gates, landing on 9997 distinct bitstrings.
- The GPU lane is not used: a pointer-chasing tree walk was 37x slower there than one CPU thread in the design measurements.

## Using the library

- Keep the qubit count a variable in any signature that mentions `Q(n)`: `main` calling `S.run(24n, ..)` directly makes the checker unfold `Q(24n)` into a pair type with 2^24 leaves. Write a function with `+n: Nat` whose result type mentions no `Q(n)` and call it with the literal, as `bench.bend` does.
- A `Nat` literal past a few thousand overflows the checker; build large counts from a `U32`. `sample` takes its shot count as a `U32` for this reason.
- Walks over a shot list are tail calls, because the JS lane uses the machine stack.
- Out of scope: OpenQASM, density matrices and noise, gate fusion, and arbitrary two-qubit unitaries as primitives.
