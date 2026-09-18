# quantum-simulator

A short, complete quantum circuit simulator in [Bend 2](https://bend-lang.com), with laws. The state is a perfect binary tree of complex `F32` amplitudes indexed by the qubit count at the type level; every gate is one generic tree walk driven by a per-qubit role list (skip, control, target); measurement and sampling are tree folds. Correctness is split three ways: shape and totality by the type checker, twenty structural laws proven in `PROOF.bend`, and numerics by golden lines and a numpy differential test. On top of that core: an exact Clifford+T scalar module with nine provable amplitude laws, arbitrary two-qubit unitaries, an OpenQASM 2 reader, and a flat-leaf hybrid state that is 4x smaller and about 4.5x faster.

## Run it

Bend 2.0.5 is required. This machine runs it through a `~/bin/bend` wrapper over a pinned clone; the [installer](https://bend-lang.com/install.sh) works too.

```sh
bend main.bend                  # the demos on the JS backend
./test.sh                       # every file with #| lines, then ref.py
bend PROOF.bend                 # All terms check.
uv run ref.py --native          # random circuits against numpy, both lanes
bend main.bend -o sim && ./sim --threads 18
./bench.sh 24:2 sample:24:10000 # native timings, see below
./bench.sh flat:24:2:12         # the hybrid, blocks of 2^12 amplitudes
QASM=examples/qft3.qasm SHOTS=4096 bend qasm.bend
```

`test.sh` also generates the exact build, `sim_x.bend` and `circuits_x.bend`: the same two sources with `amp.bend` swapped for `exact.bend`.

The JS backend is for development at 16 qubits or fewer. Native builds need clang.

## Layout

| file | what it holds |
|---|---|
| `amp.bend` | the scalar module: complex `F32` amplitudes, `Gate`, `Gate.apply`, and the named gates H X Y Z S Sdg T Tdg P RX RY RZ U |
| `sim.bend` | the state family `Q(n)`, the role walk `apply` and `mix`, the role builder, `Op` and `run`, `norm2`, `prob1`, `project`, `rescale`, `measure`, `expect_z`, the PRNG, `sums`, `shots`, `sample`, `show`, `show_hist`, `near` |
| `circuits.bend` | gate constructors for the gates both scalar modules have, `swap`, `each`, `mcz`, Grover's oracle and diffusion, two-qubit gates `two` and `ctwo` |
| `rotations.bend` | the gates with an angle (`p rx ry rz u2 u3 cp`) and `qft`, F32 only |
| `exact.bend` | the exact scalar module: amplitudes in D[w] = Z[w][1/sqrt2] over a denominator exponent, the Clifford+T gates as operations |
| `flat.bend` | the flat-leaf hybrid: a tree over blocks of amplitudes in one `Array<F32>`, with converters to and from the tree state |
| `qasm.bend`, `examples/` | the OpenQASM 2 subset reader and three example programs with their golden outputs |
| `main.bend`, `exact_demo.bend`, `flat_test.bend` | demos and tests, each printing pinned `#|` lines |
| `gates.bend` | identities that run every named gate and the two-qubit walk |
| `LAWS.bend`, `PROOF.bend`, `LAWS_exact.bend`, `PROOF_exact.bend` | the claims and their proofs, for the core and for the exact amplitudes |
| `ref.py` | the numpy differential test, and with `--exact` an exact D[w] reference, run with `uv` |
| `test.sh`, `bench.sh`, `bench.bend`, `bench_sample.bend`, `bench_flat.bend` | the test runner and the native benchmark harnesses |
| `PLAN.md`, `bend-notes.md`, `research/`, `prototype/` | the design, notes on Bend 2, the API survey and smoke findings, the verified prototypes |

## Design in one screen

- **State.** `Q(n)` is a type-level function: `Q(0n)` is one amplitude, `Q(1n+p)` a pair of `Q(p)`. A value of `Q(n)` has exactly 2^n leaves by construction, and it is linear, so a gate pass frees each node as it is matched and needs no reference counts. The root splits on qubit 0, the left child is qubit 0 = |0>, and amplitudes print root to leaf: `011` means q0=0, q1=1, q2=1 (Cirq order, the reverse of Qiskit's).
- **Gates.** `apply(n, roles, g, q)` walks down the roles: it forks at `Skip`, takes only the |1> branch at `Ctrl`, and at `Targ` hands both halves to `mix`, which zips them down to the leaves and applies the 2x2 matrix there, returning both new subtrees from one pass. Any number of controls, above or below the target, and no index arithmetic anywhere. Role lists are built by `roles(n, t, cs)`, never written by hand.
- **Circuits.** An `Op` is a target, its controls and a gate; `run` folds a list of them. `circuits.bend` has one constructor per gate, `swap` as three CNOTs, and `qft(n)`, whose H and halving controlled phases per qubit give n(n+1)/2 rotations followed by the bit-reversal swaps.
- **Measurement.** `measure(n, k, u, q)` takes the uniform `u` explicitly: it reads the probability of 1 beside the rebuilt state, projects the other branch to zeros, and rescales by 1/sqrt(p). Renormalization happens there and nowhere else, so norm drift stays visible.
- **Sampling.** `sums` turns the state into a probability tree holding, at each node, the fraction of its weight in the |0> half. `shots` routes a list of uniforms down that tree, rescaling each side back into [0, 1) and pruning empty subtrees, so 10,000 shots at 24 qubits cost about three gate passes. The PRNG is xorshift32 with a fixed default seed, so histograms are reproducible and pinned.
- **Two-qubit gates.** A 4x4 matrix of scalar entries on two targets in either order, with any controls: `apply4` walks to the shallower target, `mix4a` carries its two subtrees to the deeper one, and `mix4b` carries the four subtrees below both to the leaves. The matrix type is generic over the scalar, so the exact build has exact two-qubit gates (an iSWAP with entry w^2 is in the demo).
- **Scalar boundary.** `sim.bend` uses the scalar only through `C`, `Gate` and a handful of functions, so `exact.bend` replaces `amp.bend` behind the same names. There an amplitude is `(a + b w + c w^2 + d w^3) / sqrt2^k` with integers as differences of two Nats, kept in the canonical form with the least denominator, and the gates are a swap, a negation, rotations by w and the H butterfly, with the exact norm handed back as an F32 for probabilities and sampling. Renormalizing by 1/sqrt(p) has no exact form, so the exact build multiplies by the F32's exact dyadic value and is meant to project and read ratios rather than call `measure`. Gates with an angle are not offered there.
- **The hybrid.** `flat.bend` keeps the top `m` levels as a tree and stores each leaf's 2^lb amplitudes in one `Array<F32>`, 8 bytes per amplitude. Gates above the blocks walk the tree; where the tree code would touch two amplitudes it runs a loop over two blocks; gates inside the blocks are loops with the qubit as a bit of the index and the controls as a mask. The plan's flat-array escape hatch, measured below.
- **The reader.** `QASM=file bend qasm.bend` parses an OpenQASM 2 subset (one `qreg`, the qelib1 one-, two- and three-qubit gates, angle expressions over numbers, `pi` and the four operations, a gate on a bare register) and prints the op count, the rounded amplitudes up to five qubits, and a histogram of `SHOTS` shots; `measure` is ignored and the final state sampled instead, and unknown statements are reported and skipped. Bend has no argv or stdin, hence the environment variables; strings are lists, so it is for small files.

## What is verified

- **By the checker.** `apply : Q(n) -> Q(n)` cannot change the qubit count or the shape; every function is total by structural recursion; there is no `@unsafe` in the import graph.
- **By proof.** `bend PROOF.bend` prints `All terms check.` for twenty float-free laws: the empty and all-Skip role lists are identities; a control leaves the |0> subtree untouched; running a concatenation equals running the circuits in turn; the role list has one entry per qubit with Targ at the target and Ctrl or Skip at every other index, above and below the target; projecting twice is projecting once, projecting zeros gives zeros, and the other branch is zeros after a projection; the QFT has n(n+1)/2 rotations and three CNOTs per swap; and a histogram's counts sum to the number of uniforms whichever way each F32 comparison goes. Nothing about floats is claimed: every `F32` primitive is an opaque law, so unitarity and H H = I are not provable here. `bend PROOF_exact.bend` proves nine laws about the exact amplitudes that are: X, Y and Z are self-inverse, S and Sdg and T and Tdg undo each other in either order, and S^4 = I and T^8 = I, each by taking an amplitude and its four integers apart until eight rotations or two negations compute back to it. H H = I needs the reduction and Nat cancellation and is not claimed.
- **By golden lines.** Bell, GHZ, Toffoli, a control below its target, T^8 = I with T^7 as the negative control, the GHZ norm, expectation values, collapse under both outcomes, a 4096-shot Bell histogram inside three sigma, a biased histogram, teleportation of RY(0.7)|0> for all four outcome pairs, the QFT of |001>, Grover's probabilities 1/8, 25/32, 121/128, and eleven gate identities. The native binary prints the same lines as the JS lane.
- **By differential test.** `ref.py` draws random 5-qubit circuits over every constructor, including rotations with random angles, Haar-random one-qubit unitaries and Haar-random 4x4 unitaries with up to two controls in either target order, and compares all 32 amplitudes with a float64 numpy reference: worst error 1.0e-7 over 20 circuits of 40 gates, 1.5e-7 at 200 gates, against a tolerance of 1e-5. The native lane agreed with the JS lane to the bit. `ref.py --exact` runs Clifford+T circuits on the exact build against an independent Python D[w] reference and demands identical canonical forms: 20 circuits of 40 gates and 5 of 200, with denominator exponents up to 10, all identical on both lanes. `flat_test.bend` runs the same circuits on the hybrid and on the tree and compares them to 1e-6, with targets and controls above and inside the blocks.

## Performance

Native, no `!`, layers of H on every qubit (`./bench.sh`), on an M5 Pro with 18 cores and 48 GB. The tree and the hybrid were measured back to back on a machine with a load average near 7 from other work, so the times are upper bounds; the memory columns are exact. Blocks of 2^10 to 2^15 amplitudes.

| qubits | H gates | tree, 1 thread | tree, all cores | hybrid, 1 thread | hybrid, all cores | tree memory | hybrid memory |
|---|---|---|---|---|---|---|---|
| 20 | 100 | 0.82 s | 0.24 s | 0.16 s | 0.08 s | 34 MB | 10 MB |
| 24 | 48 | 6.6 s | 1.45 s | 1.3 s | 0.33 s | 514 MB | 130 MB |
| 26 | 52 | 25 s | 6.0 s | 5.3 s | 1.2 s | 2.05 GB | 514 MB |
| 28 | 56 | 110 s | 21.6 s | 24.5 s | 6.3 s | 8.19 GB | 2.05 GB |
| 30 | 30 | 119 s on all cores, loaded | | 55 s | 10.1 s | 32.8 GB | 8.19 GB |

- The tree costs 32 bytes per amplitude at every size, the hybrid 8; neither has a higher peak during a pass.
- The hybrid is 4.5 to 5x faster on one thread and 3.4 to 4.8x on all cores. In one block on one thread the kernel ran 24 H gates over 2^24 amplitudes in 0.23 s, about 0.6 ns per amplitude and gate.
- The ceiling on this machine is 30 qubits for the tree and would be 32 for the hybrid; neither was pushed past what fits in memory. The runtime reserves 8 TiB of address space and commits pages as it goes, so nothing in it limits the size below physical memory, and none of its fail-stops triggered up to 2^30 leaves.
- Sampling 10,000 shots at 24 qubits on the tree: 6.8 s on one thread and 1.75 s on all cores including the 24 preparation gates, landing on 9997 distinct bitstrings (loaded machine).
- The GPU lane is not used by the tree: a pointer-chasing walk was 37x slower there than one CPU thread in the design measurements. The hybrid does run on Metal when its top call is marked `!`, with the same results, but about three times slower than the CPU lane at 24 to 28 qubits: one task per block with a sequential loop inside leaves the device underused, and a device-friendly kernel would parallelize inside the blocks.

## Using the library

- Keep the qubit count a variable in any signature that mentions `Q(n)`: `main` calling `S.run(24n, ..)` directly makes the checker unfold `Q(24n)` into a pair type with 2^24 leaves. Write a function with `+n: Nat` whose result type mentions no `Q(n)` and call it with the literal, as `bench.bend` does.
- A `Nat` literal past a few thousand overflows the checker; build large counts from a `U32`. `sample` takes its shot count as a `U32` for this reason.
- Walks over a shot list are tail calls, because the JS lane uses the machine stack.
- The exact build is generated, not committed: `test.sh` and `ref.py --exact` write `sim_x.bend` and `circuits_x.bend` beside the sources. Files that import them (`exact_demo.bend`, `LAWS_exact.bend`) need that step first.
- Constructor names are global across the import graph, so a new type may not reuse a name Base declares (`GT`, `Word`), and `Kind` is a keyword.
- Out of scope: density matrices and noise, gate fusion, and mid-circuit measurement with classical control in the QASM reader.
