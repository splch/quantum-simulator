# prototype/ - smoke tests run on 2026-09-17 against Bend 2.0.5

Evidence for PLAN.md, not the product. Run any file with `bend <file>` or, without an install, `BEND_NO_TELEMETRY=1 bun <bend-clone>/bend2/main.ts <file>`.

| file | what it shows | observed output |
|---|---|---|
| `q.bend` | the core: depth-indexed state `Q(n)`, roles walk `apply`/`mix`, H then CNOT on 2 qubits | `0.70710677+0i 0+0i 0+0i 0.70710677+0i` |
| `qctrl.bend` | control below the target: H on qubit 2, CNOT control 2 target 0 | `0.7071` at indices 0 and 5 |
| `qccz.bend` | two controls (Toffoli) and a role list shorter than the qubit count | amplitude `1` at index 7 |
| `laws.bend` | `nil_id` and `skip_id` proven by induction on `n` | `All terms check.` |
| `rng.bend` | xorshift32, hash finalizer, U32 to uniform F32, `F32.sqrt`, `F32.sin`, `F32.pi` | see `research/bend-findings.md` |
| `qbench.bend` | timing harness: `NQ` qubits, `NL` layers of H on every qubit; `sed` the placeholders, then `bend qb.bend -o qb` | 24 qubits, 48 gates: 3.52 s on 1 thread, 0.49 s on 18, 539 MB |
