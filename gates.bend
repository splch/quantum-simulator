import Base
import ./amp.bend as A
import ./sim.bend as S
import ./circuits.bend as G

# Identities that run every named gate the demos in main.bend do not, each
# checked to 1e-6 per amplitude. The rotations take their angles from
# F32.pi(), so these are tolerance checks rather than pinned amplitudes.

# both circuits on |0..0> reach the same state
def eq(+n: Nat, a: List<&2, S.Op>, b: List<&2, S.Op>) -> Bool:
  S.near(n, 1.0e-12, S.run(n, a, S.ket0(n)), S.run(n, b, S.ket0(n)))

def half_pi() -> F32:
  F32.mul(F32.pi(), 0.5)

# H with its matrix spelled out through U
def h_raw() -> S.Op:
  G.ctrl(Nil{}, 0n, A.U(A.C{A.rh(), 0.0}, A.C{A.rh(), 0.0}, A.C{A.rh(), 0.0}, A.C{F32.neg(A.rh()), 0.0}))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("S S = Z on |+>: " ++ Bool.show(eq(1n, [G.h(0n), G.s(0n), G.s(0n)], [G.h(0n), G.z(0n)])))
    IO.print("S Sdg = I on |+>: " ++ Bool.show(eq(1n, [G.h(0n), G.s(0n), G.sdg(0n)], [G.h(0n)])))
    IO.print("T Tdg = I on |+>: " ++ Bool.show(eq(1n, [G.h(0n), G.t(0n), G.tdg(0n)], [G.h(0n)])))
    IO.print("Y|0> = S X|0> = i|1>: " ++ Bool.show(eq(1n, [G.y(0n)], [G.x(0n), G.s(0n)])))
    IO.print("P(pi/2) = S on |+>: " ++ Bool.show(eq(1n, [G.h(0n), G.p(half_pi(), 0n)], [G.h(0n), G.s(0n)])))
    IO.print("RX(pi)|0> = Sdg X|0> = -i|1>: " ++ Bool.show(eq(1n, [G.rx(F32.pi(), 0n)], [G.x(0n), G.sdg(0n)])))
    IO.print("RY(pi/2)|0> = H|0>: " ++ Bool.show(eq(1n, [G.ry(half_pi(), 0n)], [G.h(0n)])))
    IO.print("RZ(pi) = S X Sdg X = diag(-i, i) on |+>: " ++ Bool.show(eq(1n, [G.h(0n), G.rz(F32.pi(), 0n)], [G.h(0n), G.x(0n), G.sdg(0n), G.x(0n), G.s(0n)])))
    IO.print("U(H entries) = H: " ++ Bool.show(eq(1n, [h_raw()], [G.h(0n)])))
    IO.print("CZ = (I x H) CX (I x H) on |++>: " ++ Bool.show(eq(2n, [G.h(0n), G.h(1n), G.cz(0n, 1n)], [G.h(0n), G.h(1n), G.h(1n), G.cx(0n, 1n), G.h(1n)])))
    IO.print("CP(pi) = CZ on |++>: " ++ Bool.show(eq(2n, [G.h(0n), G.h(1n), G.cp(F32.pi(), 0n, 1n)], [G.h(0n), G.h(1n), G.cz(0n, 1n)])))
    IO.print("swap(0, 2)|001> = |100>: " ++ Bool.show(eq(3n, List.append(&2, S.Op, [G.x(2n)], G.swap(0n, 2n)), [G.x(0n)])))
    IO.print("qft(4) op count, 10 rotations + 6 swap CNOTs: " ++ Nat.show(List.length(&2, S.Op, G.qft(4n))))
    IO.print("QFT|+++> = |000>: " ++ Bool.show(eq(3n, List.append(&2, S.Op, G.each(~G.h, 3n), G.qft(3n)), Nil{})))

#|S S = Z on |+>: True
#|S Sdg = I on |+>: True
#|T Tdg = I on |+>: True
#|Y|0> = S X|0> = i|1>: True
#|P(pi/2) = S on |+>: True
#|RX(pi)|0> = Sdg X|0> = -i|1>: True
#|RY(pi/2)|0> = H|0>: True
#|RZ(pi) = S X Sdg X = diag(-i, i) on |+>: True
#|U(H entries) = H: True
#|CZ = (I x H) CX (I x H) on |++>: True
#|CP(pi) = CZ on |++>: True
#|swap(0, 2)|001> = |100>: True
#|qft(4) op count, 10 rotations + 6 swap CNOTs: 16
#|QFT|+++> = |000>: True
