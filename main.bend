import Base
import ./sim.bend as S
import ./circuits.bend as G

# Each demo prints one line, pinned below as a #| line. Amplitudes print root
# to leaf, so the bitstring 011 means q0=0, q1=1, q2=1.

# (|00> + |11>)/sqrt2
def bell() -> String:
  S.show(2n, S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n)))

# (|000> + |111>)/sqrt2
def ghz() -> String:
  S.show(3n, S.run(3n, [G.h(0n), G.cx(0n, 1n), G.cx(1n, 2n)], S.ket0(3n)))

# |110> -> |111> under a Toffoli with two controls
def toffoli() -> String:
  S.show(3n, S.run(3n, [G.x(0n), G.x(1n), G.ccx(0n, 1n, 2n)], S.ket0(3n)))

# the control below the target: H on qubit 2, then CNOT from 2 to 0, gives
# (|000> + |101>)/sqrt2
def below() -> String:
  S.show(3n, S.run(3n, [G.h(2n), G.cx(2n, 0n)], S.ket0(3n)))

# k T gates on |+>, compared with |+> to 1e-6 per amplitude: True for k = 8,
# since T^8 = I, and False for the negative control k = 7
def tpow(k: Nat) -> String:
  plus = S.run(1n, [G.h(0n)], S.ket0(1n))
  back = S.run(1n, G.h(0n) <> List.replicate(S.Op, k, G.t(0n)), S.ket0(1n))
  Bool.show(S.near(1n, 1.0e-12, back, plus))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(bell())
    IO.print(ghz())
    IO.print(toffoli())
    IO.print(below())
    IO.print(tpow(8n) ++ " " ++ tpow(7n))

#|0.70710677+0i 0+0i 0+0i 0.70710677+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i
#|0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 1+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i 0+0i 0+0i
#|True False
