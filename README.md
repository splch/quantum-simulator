# bend2-quantum-simulator

A short, complete quantum circuit simulator in [Bend 2](https://bend-lang.com). The state is a perfect binary tree of complex `F32` amplitudes indexed by the qubit count at the type level; every gate is one generic tree walk driven by a per-qubit role list (skip, control, target); measurement and sampling are tree folds. Shape and totality are checked by the types, numerics by pinned lines and a numpy differential test.

## Run it

Bend 2.0.5 is required; this machine runs it through a `~/bin/bend` wrapper over a pinned clone, and the [installer](https://bend-lang.com/install.sh) works too. The JS backend is for development at 16 qubits or fewer; native builds need clang.

```sh
bend tests/demos.bend                                # the demos and identities on the JS backend
./test.sh                                            # the pinned lines, then tests/ref.py
uv run tests/ref.py --native                         # random circuits against numpy, both lanes
bend tests/demos.bend -o /tmp/demos && /tmp/demos --threads 18
```

## Layout

```
src/sim.bend       amplitudes and gates, the state Q(n), the role walk, Op and run, readout, measurement, sampling
src/circuits.bend  one constructor per gate (h x y z s sdg t tdg cx cz ccx p rx ry rz u2 u3 cp), swap, each, mcz, Grover's oracle and diffusion, qft
tests/demos.bend   Bell, GHZ, Toffoli, T^8, the norm, expectations, collapse, histograms, teleportation, the QFT, Grover and fourteen gate identities, each line pinned as a #| comment
tests/ref.py       random 5-qubit circuits over every constructor against a float64 numpy reference
test.sh            runs everything
```

## Design

- **State.** `Q(n)` is a type-level function: `Q(0n)` is one amplitude, `Q(1n+p)` a pair of `Q(p)`. A value has exactly 2^n leaves by construction and is linear, so a gate pass frees each node as it is matched. The root splits on qubit 0, the left child is qubit 0 = |0>, and amplitudes print root to leaf: `011` means q0=0, q1=1, q2=1 (Cirq order, the reverse of Qiskit's).
- **Gates.** `apply(n, roles, g, q)` walks down the roles: it forks at `Skip`, takes only the |1> branch at `Ctrl`, and at `Targ` hands both halves to `mix`, which zips them to the leaves and applies the 2x2 matrix there, returning both new subtrees from one pass. Any number of controls, above or below the target, and no index arithmetic. Role lists come from `roles(n, t, cs)`, never by hand.
- **Circuits.** An `Op` is a target, its controls and a gate; `run` folds a list of them. `qft(n)` is H and halving controlled phases per qubit, n(n+1)/2 rotations, then the bit-reversal swaps.
- **Measurement.** `measure(n, k, u, q)` takes the uniform `u` explicitly: it reads the probability of 1 beside the rebuilt state, projects the other branch to zeros and rescales by 1/sqrt(p). Renormalization happens there and nowhere else, so norm drift stays visible.
- **Sampling.** `sums` turns the state into a probability tree holding, at each node, the fraction of its weight in the |0> half; `shots` routes a list of uniforms down it, rescaling each side back into [0, 1) and pruning empty subtrees, so 10,000 shots at 24 qubits cost about three gate passes. The PRNG is xorshift32 with a finalizer and a fixed default seed, so histograms are pinned.

## Verified

- **By the checker.** `apply : Q(n) -> Q(n)` cannot change the qubit count or the shape, every function is total by structural recursion, and nothing is `@unsafe`.
- **By pinned lines.** Thirty-four lines: Bell, GHZ, Toffoli, a control below its target, T^8 = I with T^7 as the negative control, the GHZ norm, expectation values, collapse under both outcomes, a 4096-shot Bell histogram inside three sigma, a biased histogram, teleportation of RY(0.7)|0> for all four outcome pairs, the QFT of |001>, Grover's probabilities 1/8, 25/32, 121/128, and fourteen gate identities. The native binary prints the same lines as the JS lane.
- **By differential test.** `ref.py` draws random 5-qubit circuits over every constructor, with random angles, Haar-random one-qubit unitaries and up to three controls, and compares all 32 amplitudes with a float64 numpy reference: worst error 9.5e-8 over 20 circuits of 40 gates, against a tolerance of 1e-5.

## Performance

Native, layers of H on every qubit, measured on an M5 Pro with 18 cores and 48 GB: 24 qubits and 48 gates take 6.6 s on one thread and 1.45 s on all cores in 514 MB; 28 qubits and 56 gates 110 s and 21.6 s in 8.2 GB; 30 qubits fit in 32.8 GB. The state costs 32 bytes per amplitude with no higher peak during a pass. Sampling 10,000 shots at 24 qubits took 1.75 s on all cores including the preparation gates. The GPU lane is not used: a pointer-chasing walk was 37x slower there than one CPU thread.

## Notes for Bend

- Keep the qubit count a variable in any signature that mentions `Q(n)`: `main` calling `S.run(24n, ..)` directly makes the checker unfold `Q(24n)` into a pair type with 2^24 leaves. Write a function with `+n: Nat` whose result type mentions no `Q(n)` and call it with the literal.
- A `Nat` literal past a few thousand overflows the checker; build large counts from a `U32`, as `sample` does for its shot count.
- Walks over a shot list are tail calls, because the JS lane uses the machine stack.
- Constructor names are global across the import graph, so a new type may not reuse a name Base declares (`GT`, `Word`), and `Kind` is a keyword.
