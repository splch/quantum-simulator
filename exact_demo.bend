import Base
import ./exact.bend as A
import ./sim_x.bend as S
import ./circuits_x.bend as G

# The simulator over the exact scalar module: the same sim.bend and
# circuits.bend with amp.bend swapped for exact.bend (test.sh generates
# sim_x.bend and circuits_x.bend). Amplitudes print as [a b c d]/rt2^k for
# (a + b w + c w^2 + d w^3) / sqrt2^k, w = e^(i pi/4). Each line is pinned.

def bell() -> S.Q(2n):
  S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n))

# probability of qubit 0 reading 1 in the Bell state, and the state's norm
def bell_p1.fin(r: F32 & S.Q(2n)) -> String:
  (p, q) = r
  F32.show(p) ++ ", norm " ++ F32.show(S.norm2(2n, q))

# i = w^2, and iSWAP as a 4x4 with exact entries
def ci() -> A.C:
  A.C{A.Int{0n, 0n}, A.Int{0n, 0n}, A.Int{1n, 0n}, A.Int{0n, 0n}, 0n}

def iswap() -> S.Gate4:
  S.Gate4{S.Row{A.C.one(), A.C.zero(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.zero(), ci(), A.C.zero()}, S.Row{A.C.zero(), ci(), A.C.zero(), A.C.zero()}, S.Row{A.C.zero(), A.C.zero(), A.C.zero(), A.C.one()}}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Bell: " ++ S.show(2n, bell()))
    IO.print("GHZ: " ++ S.show(3n, S.run(3n, [G.h(0n), G.cx(0n, 1n), G.cx(1n, 2n)], S.ket0(3n))))
    IO.print("T|+>: " ++ S.show(1n, S.run(1n, [G.h(0n), G.t(0n)], S.ket0(1n))))
    IO.print("T^8|+>: " ++ S.show(1n, S.run(1n, G.h(0n) <> List.replicate(S.Op, 8n, G.t(0n)), S.ket0(1n))))
    IO.print("H H|0>: " ++ S.show(1n, S.run(1n, [G.h(0n), G.h(0n)], S.ket0(1n))))
    IO.print("S S|+>: " ++ S.show(1n, S.run(1n, [G.h(0n), G.s(0n), G.s(0n)], S.ket0(1n))))
    IO.print("Y|0>: " ++ S.show(1n, S.run(1n, [G.y(0n)], S.ket0(1n))))
    IO.print("Toffoli |110>: " ++ S.show(3n, S.run(3n, [G.x(0n), G.x(1n), G.ccx(0n, 1n, 2n)], S.ket0(3n))))
    IO.print("H T H|0>: " ++ S.show(1n, S.run(1n, [G.h(0n), G.t(0n), G.h(0n)], S.ket0(1n))))
    IO.print("Bell p1 of qubit 0: " ++ bell_p1.fin(S.prob1(2n, 0n, bell())))
    IO.print("project Bell onto qubit 0 = 1: " ++ S.show(2n, S.project(2n, 0n, True{}, bell())))
    IO.print(S.show_hist(S.sample(2n, 4096, S.seed(), bell())))
    IO.print("4x4 CNOT Bell: " ++ S.show(2n, S.run(2n, [G.h(0n), G.cx4(0n, 1n)], S.ket0(2n))))
    IO.print("iSWAP|01> = i|10>: " ++ S.show(2n, S.run(2n, [G.x(1n), G.two(0n, 1n, iswap())], S.ket0(2n))))

#|Bell: [1 0 0 0]/rt2^1 [0 0 0 0] [0 0 0 0] [1 0 0 0]/rt2^1
#|GHZ: [1 0 0 0]/rt2^1 [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [1 0 0 0]/rt2^1
#|T|+>: [1 0 0 0]/rt2^1 [0 1 0 0]/rt2^1
#|T^8|+>: [1 0 0 0]/rt2^1 [1 0 0 0]/rt2^1
#|H H|0>: [1 0 0 0] [0 0 0 0]
#|S S|+>: [1 0 0 0]/rt2^1 [-1 0 0 0]/rt2^1
#|Y|0>: [0 0 0 0] [0 0 1 0]
#|Toffoli |110>: [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [0 0 0 0] [1 0 0 0]
#|H T H|0>: [1 1 0 0]/rt2^2 [1 -1 0 0]/rt2^2
#|Bell p1 of qubit 0: 0.5, norm 1
#|project Bell onto qubit 0 = 1: [0 0 0 0] [0 0 0 0] [0 0 0 0] [1 0 0 0]/rt2^1
#|00 2058
#|11 2038
#|4x4 CNOT Bell: [1 0 0 0]/rt2^1 [0 0 0 0] [0 0 0 0] [1 0 0 0]/rt2^1
#|iSWAP|01> = i|10>: [0 0 0 0] [0 0 0 0] [0 0 1 0] [0 0 0 0]
