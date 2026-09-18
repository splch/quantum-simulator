# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy"]
# ///
"""Differential test: random circuits over the whole gate set, run by the Bend
simulator and by a numpy reference, with every amplitude compared to 1e-5.

    uv run ref.py                  # 20 circuits of 40 gates on 5 qubits, JS lane
    uv run ref.py --native         # also build and run the native binary
    uv run ref.py --seed 7 --keep  # keep diff_tmp.bend for a look

Qubit 0 is the most significant bit on both sides. The generated program is
written beside this script as diff_tmp.bend (gitignored), because a Bend
import is relative to the importing file. Angles and raw-unitary entries are
rounded to F32 before both sides see them, so the only differences left are
the simulator's F32 arithmetic against numpy's float64.
"""
import argparse
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TMP = HERE / "diff_tmp.bend"
RH = 1 / math.sqrt(2)


def f32(x):
    """The F32 value Bend will see, as a Python float."""
    return float(np.float32(x))


def lit(x):
    """A Bend F32 literal. There are no negative literals, so F32.neg wraps them."""
    s = np.format_float_positional(np.float32(abs(x)), unique=True, trim="0")
    return f"F32.neg({s})" if x < 0 else s


def c_lit(z):
    return f"A.C{{{lit(z.real)}, {lit(z.imag)}}}"


def nats(qs):
    return "[" + ", ".join(f"{q}n" for q in qs) + "]"


# one-qubit gates: name -> (Bend constructor, Bend gate value, numpy matrix)
def one_qubit_table(rng):
    phi, th = f32(rng.uniform(0, 2 * math.pi)), f32(rng.uniform(0, 2 * math.pi))
    c, s = math.cos(th / 2), math.sin(th / 2)
    return {
        "h": ("G.h", "A.H()", np.array([[RH, RH], [RH, -RH]], complex)),
        "x": ("G.x", "A.X()", np.array([[0, 1], [1, 0]], complex)),
        "y": ("G.y", "A.Y()", np.array([[0, -1j], [1j, 0]])),
        "z": ("G.z", "A.Z()", np.diag([1, -1]).astype(complex)),
        "s": ("G.s", "A.S()", np.diag([1, 1j])),
        "sdg": ("G.sdg", "A.Sdg()", np.diag([1, -1j])),
        "t": ("G.t", "A.T()", np.diag([1, np.exp(1j * math.pi / 4)])),
        "tdg": ("G.tdg", "A.Tdg()", np.diag([1, np.exp(-1j * math.pi / 4)])),
        "p": (f"G.p({lit(phi)}, ", f"A.P({lit(phi)})", np.diag([1, np.exp(1j * phi)])),
        "rx": (f"G.rx({lit(th)}, ", f"A.RX({lit(th)})", np.array([[c, -1j * s], [-1j * s, c]])),
        "ry": (f"G.ry({lit(th)}, ", f"A.RY({lit(th)})", np.array([[c, -s], [s, c]], complex)),
        "rz": (f"G.rz({lit(th)}, ", f"A.RZ({lit(th)})", np.diag([np.exp(-1j * th / 2), np.exp(1j * th / 2)])),
    }


def random_unitary(rng):
    """A Haar-random 2x2 unitary with its entries rounded to F32 (both sides use these)."""
    q, r = np.linalg.qr(rng.normal(size=(2, 2)) + 1j * rng.normal(size=(2, 2)))
    q = q * (np.diag(r) / np.abs(np.diag(r)))
    return np.array([[complex(f32(z.real), f32(z.imag)) for z in row] for row in q])


def random_gate(rng, n):
    """One random gate: (Bend text, is it a list-valued segment, [(controls, target, matrix)])."""
    table = one_qubit_table(rng)
    kind = rng.choice(["one", "cx", "cz", "cp", "swap", "ccx", "ctrl_named", "ctrl_u"],
                      p=[0.34, 0.12, 0.08, 0.08, 0.08, 0.08, 0.12, 0.10])
    if kind == "one":
        name = rng.choice(list(table))
        ctor, _, m = table[name]
        q = int(rng.integers(n))
        text = f"{ctor}{q}n)" if ctor.endswith(", ") else f"{ctor}({q}n)"
        return text, False, [([], q, m)]
    if kind in ("cx", "cz", "cp"):
        c, q = (int(v) for v in rng.choice(n, 2, replace=False))
        if kind == "cx":
            return f"G.cx({c}n, {q}n)", False, [([c], q, table["x"][2])]
        if kind == "cz":
            return f"G.cz({c}n, {q}n)", False, [([c], q, table["z"][2])]
        phi = f32(rng.uniform(0, 2 * math.pi))
        return f"G.cp({lit(phi)}, {c}n, {q}n)", False, [([c], q, np.diag([1, np.exp(1j * phi)]))]
    if kind == "swap":
        a, b = (int(v) for v in rng.choice(n, 2, replace=False))
        x = table["x"][2]
        return f"G.swap({a}n, {b}n)", True, [([a], b, x), ([b], a, x), ([a], b, x)]
    if kind == "ccx":
        c1, c2, q = (int(v) for v in rng.choice(n, 3, replace=False))
        return f"G.ccx({c1}n, {c2}n, {q}n)", False, [([c1, c2], q, table["x"][2])]
    k = int(rng.integers(1, min(4, n)))            # 1 to 3 controls
    *cs, q = (int(v) for v in rng.choice(n, k + 1, replace=False))
    if kind == "ctrl_named":
        name = rng.choice(list(table))
        _, gate, m = table[name]
    else:
        m = random_unitary(rng)
        gate = f"A.U({c_lit(m[0, 0])}, {c_lit(m[0, 1])}, {c_lit(m[1, 0])}, {c_lit(m[1, 1])})"
    return f"G.ctrl({nats(cs)}, {q}n, {gate})", False, [(cs, q, m)]


def random_circuit(rng, n, gates):
    """Bend segments for List.concat, and the flat gate list for numpy."""
    segments, run, flat = [], [], []
    for _ in range(gates):
        text, is_list, ops = random_gate(rng, n)
        flat += ops
        if is_list:
            if run:
                segments.append("[" + ", ".join(run) + "]")
                run = []
            segments.append(text)
        else:
            run.append(text)
    if run:
        segments.append("[" + ", ".join(run) + "]")
    return segments, flat


def emit(n, segments):
    ops = ", ".join(segments)
    return (
        "import Base\nimport ./amp.bend as A\nimport ./sim.bend as S\nimport ./circuits.bend as G\n\n"
        "def main() -> IO(Unit):\n"
        f"  IO.print(S.show({n}n, S.run({n}n, List.concat(&2, S.Op, [{ops}]), S.ket0({n}n))))\n"
    )


def apply(psi, n, cs, t, m):
    """The gate m on target t with controls cs; qubit 0 is the most significant bit."""
    out = psi.copy()
    bit = lambda i, q: (i >> (n - 1 - q)) & 1
    for i in range(1 << n):
        if bit(i, t) or not all(bit(i, c) for c in cs):
            continue
        j = i | (1 << (n - 1 - t))
        a, b = psi[i], psi[j]
        out[i] = m[0, 0] * a + m[0, 1] * b
        out[j] = m[1, 0] * a + m[1, 1] * b
    return out


AMP = re.compile(r"^(-?[0-9.]+(?:e-?[0-9]+)?)([+-][0-9.]+(?:e-?[0-9]+)?)i$")


def parse(line):
    out = []
    for tok in line.split():
        m = AMP.match(tok)
        if not m:
            sys.exit(f"cannot parse amplitude {tok!r} in: {line}")
        out.append(complex(float(m[1]), float(m[2])))
    return np.array(out)


def run_cmd(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if r.returncode:
        sys.exit(f"{' '.join(cmd)} failed:\n{r.stdout}{r.stderr}")
    lines = r.stdout.strip().splitlines()
    return lines[-1] if lines else ""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--qubits", type=int, default=5)
    ap.add_argument("--gates", type=int, default=40)
    ap.add_argument("--circuits", type=int, default=20)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--tol", type=float, default=1e-5)
    ap.add_argument("--native", action="store_true", help="also build and run the native binary")
    ap.add_argument("--keep", action="store_true", help="leave diff_tmp.bend in place")
    args = ap.parse_args()
    n, ok, worst = args.qubits, True, 0.0
    exe = HERE / "diff_tmp"
    for k in range(args.circuits):
        seed = args.seed + k
        rng = np.random.default_rng(seed)
        segments, flat = random_circuit(rng, n, args.gates)
        TMP.write_text(emit(n, segments))
        psi = np.zeros(1 << n, complex)
        psi[0] = 1
        for cs, t, m in flat:
            psi = apply(psi, n, cs, t, m)
        js = parse(run_cmd(["bend", str(TMP)]))
        err = float(np.max(np.abs(js - psi)))
        line = f"seed {seed:3d}: {len(flat):3d} ops, |bend - numpy| max {err:.1e}, norm {np.sum(np.abs(js) ** 2):.7f}"
        if args.native:
            run_cmd(["bend", str(TMP), "-o", str(exe)])
            nat = parse(run_cmd([str(exe)]))
            exe.unlink()
            errn = float(np.max(np.abs(nat - psi)))
            line += f"; native {errn:.1e}, native vs js {np.max(np.abs(nat - js)):.1e}"
            err = max(err, errn)
        print(line)
        worst = max(worst, err)
        ok &= err <= args.tol
    if not args.keep:
        TMP.unlink(missing_ok=True)
    print(f"{'PASS' if ok else 'FAIL'}: {args.circuits} circuits of {args.gates} gates on {n} qubits, worst {worst:.1e} against {args.tol:.0e}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
