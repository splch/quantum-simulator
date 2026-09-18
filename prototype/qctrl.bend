import Base
import ./q.bend as S

# 3 qubits, root = qubit 0. H on qubit 2, then CNOT with control qubit 2 and target qubit 0.
# Expect (|000> + |101>)/sqrt2: amplitudes 0.7071 at index 0 and index 5.
def main() -> IO(Unit):
  q0 = S.ket0(3n)
  q1 = S.apply(3n, [S.Skip{}, S.Skip{}, S.Targ{}], S.H(), q0)
  q2 = S.apply(3n, [S.Targ{}, S.Skip{}, S.Ctrl{}], S.X(), q1)
  IO.print(S.show(3n, q2))
