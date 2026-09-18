import Base
import ./amp.bend as A
import ./sim.bend as S
import ./circuits.bend as G
import ./rotations.bend as R
import ./flat.bend as F

# The hybrid against the tree: each circuit runs on both representations
# (five qubits: a tree of depth 3 over blocks of 4 amplitudes), the hybrid's
# state is converted to a tree, and the two are compared to 1e-6. Targets
# and controls fall above and inside the blocks.

def same(+ops: List<&2, S.Op>) -> Bool:
  S.near(5n, 1.0e-12, F.to_tree(3n, 2n, F.runf(3n, 2n, ops, F.ketf(3n, 2n))), S.run(5n, ops, S.ket0(5n)))

# every amplitude distinct before the gate under test
def prep() -> List<&2, S.Op>:
  [G.h(0n), G.t(0n), G.h(1n), G.s(1n), G.h(3n), G.t(3n), G.h(4n), G.cx(0n, 4n), R.ry(0.7, 2n)]

def with(ops: List<&2, S.Op>) -> List<&2, S.Op>:
  List.append(&2, S.Op, prep(), ops)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Bell on the hybrid: " ++ F.showf(1n, 1n, F.runf(1n, 1n, [G.h(0n), G.cx(0n, 1n)], F.ketf(1n, 1n))))
    IO.print("H on every qubit, tree part and block part: " ++ Bool.show(same(G.each(~G.h, 5n))))
    IO.print("target above, control above: " ++ Bool.show(same(with([G.cx(0n, 2n), G.cz(1n, 0n)]))))
    IO.print("target above, control inside: " ++ Bool.show(same(with([G.cx(4n, 1n), G.cz(3n, 2n)]))))
    IO.print("target inside, control above: " ++ Bool.show(same(with([G.cx(1n, 3n), G.ctrl([0n, 2n], 4n, A.Y())]))))
    IO.print("target inside, control inside: " ++ Bool.show(same(with([G.cx(3n, 4n), G.cz(4n, 3n)]))))
    IO.print("three controls across the boundary: " ++ Bool.show(same(with([G.ctrl([0n, 2n, 4n], 3n, A.X()), G.ctrl([1n, 3n, 4n], 0n, A.H())]))))
    IO.print("phases and rotations everywhere: " ++ Bool.show(same(with([G.t(4n), G.sdg(2n), R.rz(0.3, 3n), R.p(1.1, 0n), R.cp(0.4, 4n, 1n)]))))
    IO.print("the QFT on five qubits: " ++ Bool.show(same(R.qft(5n))))
    IO.print("a two-qubit gate through the round trip: " ++ Bool.show(same(with([G.two(3n, 1n, S.Gate4{S.Row{A.C.one(), A.C.zero(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.zero(), A.C.one(), A.C.zero()}, S.Row{A.C.zero(), A.C.one(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.zero(), A.C.zero(), A.C.one()}})]))))
    IO.print("norm of the hybrid GHZ: " ++ F32.show(F.norm2f(3n, 2n, F.runf(3n, 2n, [G.h(0n), G.cx(0n, 1n), G.cx(1n, 2n), G.cx(2n, 3n), G.cx(3n, 4n)], F.ketf(3n, 2n)))))
    IO.print("tree to hybrid and back: " ++ Bool.show(S.near(5n, 1.0e-12, F.to_tree(3n, 2n, F.of_tree(3n, 2n, S.run(5n, prep(), S.ket0(5n)))), S.run(5n, prep(), S.ket0(5n)))))

#|Bell on the hybrid: 0.70710677+0i 0+0i 0+0i 0.70710677+0i
#|H on every qubit, tree part and block part: True
#|target above, control above: True
#|target above, control inside: True
#|target inside, control above: True
#|target inside, control inside: True
#|three controls across the boundary: True
#|phases and rotations everywhere: True
#|the QFT on five qubits: True
#|a two-qubit gate through the round trip: True
#|norm of the hybrid GHZ: 0.99999994
#|tree to hybrid and back: True
