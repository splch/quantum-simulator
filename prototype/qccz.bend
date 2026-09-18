import Base
import ./q.bend as S

# Toffoli via two controls: |110> -> |111>. Prepare |110> with X on qubits 0 and 1, then CCX(ctrl 0, ctrl 1, target 2).
# Expect amplitude 1 at index 7.
def main() -> IO(Unit):
  q0 = S.ket0(3n)
  q1 = S.apply(3n, [S.Targ{}], S.X(), q0)
  q2 = S.apply(3n, [S.Skip{}, S.Targ{}], S.X(), q1)
  q3 = S.apply(3n, [S.Ctrl{}, S.Ctrl{}, S.Targ{}], S.X(), q2)
  IO.print(S.show(3n, q3))
