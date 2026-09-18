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

# Measurement and sampling
# ------------------------

# the norm of the GHZ state: 2 rh^2 in F32, which makes the rounding of the
# 1/sqrt2 literal visible as 1 - 6e-8
def ghz_norm() -> String:
  F32.show(S.norm2(3n, S.run(3n, [G.h(0n), G.cx(0n, 1n), G.cx(1n, 2n)], S.ket0(3n))))

def bit(b: Bool) -> String:
  match b:
    case False{}:
      "0"
    case True{}:
      "1"

# <Z_0> on |0> and on |1>
def zexp.fin(r: F32 & S.Q(1n)) -> String:
  (z, q) = r
  F32.show(z)

def zexp() -> String:
  zexp.fin(S.expect_z(1n, 0n, S.ket0(1n))) ++ " " ++ zexp.fin(S.expect_z(1n, 0n, S.run(1n, [G.x(0n)], S.ket0(1n))))

# measure qubit 0 of a Bell state with the uniform u: the outcome, and whether
# the collapsed and renormalized state equals the circuit want on |00> to 1e-6
def collapse.fin(want: List<&2, S.Op>, r: Bool & S.Q(2n)) -> String:
  (m, q) = r
  bit(m) ++ " " ++ Bool.show(S.near(2n, 1.0e-12, q, S.run(2n, want, S.ket0(2n))))

def collapse(u: F32, want: List<&2, S.Op>) -> String:
  collapse.fin(want, S.measure(2n, 0n, u, S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n))))

# 4096 shots of the Bell state from the default seed
def bell_hist() -> List<&2, S.Bin>:
  S.sample(2n, 4096, S.seed(), S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n)))

# within 3 sigma of 2048, where sigma is sqrt(4096 / 4) = 32
def within(+count: Nat) -> Bool:
  Nat.is_le(1952n, count) && Nat.is_le(count, 2144n)

# exactly the bins 00 and 11, each within 3 sigma
def bell_ok(bins: List<&2, S.Bin>) -> Bool:
  match bins:
    case S.Bin{s0, a} <> S.Bin{s1, b} <> Nil{}:
      String.eq(s0, "00") && within(a) && String.eq(s1, "11") && within(b)
    case _:
      False{}

# Teleport RY(0.7)|0> from qubit 0 to qubit 2 through a Bell pair on qubits 1
# and 2. The uniforms u0 and u1 drive the two measurements; the corrections
# X^m1 then Z^m0 act on qubit 2. teleport returns both outcomes and the state.
def fixes(m0: Bool, m1: Bool) -> List<&2, S.Op>:
  match m0 m1:
    case False{} False{}:
      Nil{}
    case False{} True{}:
      [G.x(2n)]
    case True{} False{}:
      [G.z(2n)]
    case True{} True{}:
      [G.x(2n), G.z(2n)]

def teleport.fix(+m0: Bool, r: Bool & S.Q(3n)) -> Bool & Bool & S.Q(3n):
  (+m1, q) = r
  (m0, m1, S.run(3n, fixes(m0, m1), q))

def teleport.m1(u1: F32, r: Bool & S.Q(3n)) -> Bool & Bool & S.Q(3n):
  (m0, q) = r
  teleport.fix(m0, S.measure(3n, 1n, u1, q))

def teleport(u0: F32, u1: F32) -> Bool & Bool & S.Q(3n):
  teleport.m1(u1, S.measure(3n, 0n, u0, S.run(3n, [G.ry(0.7, 0n), G.h(1n), G.cx(1n, 2n), G.cx(0n, 1n), G.h(0n)], S.ket0(3n))))

# |m0 m1> (x) RY(0.7)|0>: what teleportation must leave behind
def prep(m0: Bool, m1: Bool) -> List<&2, S.Op>:
  match m0 m1:
    case False{} False{}:
      [G.ry(0.7, 2n)]
    case False{} True{}:
      [G.x(1n), G.ry(0.7, 2n)]
    case True{} False{}:
      [G.x(0n), G.ry(0.7, 2n)]
    case True{} True{}:
      [G.x(0n), G.x(1n), G.ry(0.7, 2n)]

# the outcomes, and whether the final state matches prep to 1e-6 per amplitude
def tele.fin(r: Bool & Bool & S.Q(3n)) -> String:
  (+m0, +m1, q) = r
  bit(m0) ++ bit(m1) ++ ":" ++ Bool.show(S.near(3n, 1.0e-12, q, S.run(3n, prep(m0, m1), S.ket0(3n))))

def tele(u0: F32, u1: F32) -> String:
  tele.fin(teleport(u0, u1))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(bell())
    IO.print(ghz())
    IO.print(toffoli())
    IO.print(below())
    IO.print(tpow(8n) ++ " " ++ tpow(7n))
    IO.print("norm of GHZ: " ++ ghz_norm())
    IO.print("<Z0> on |0> and |1>: " ++ zexp())
    IO.print("measure q0 of Bell, u = 0.9 then 0.1: " ++ collapse(0.9, Nil{}) ++ ", " ++ collapse(0.1, [G.x(0n), G.x(1n)]))
    IO.print("4096 Bell shots, two bins within 3 sigma: " ++ Bool.show(bell_ok(bell_hist())))
    IO.print(S.show_hist(bell_hist()))
    IO.print("4096 shots of RY(0.7)|0> (x) Bell(1, 2), expect 1807 1807 241 241:")
    IO.print(S.show_hist(S.sample(3n, 4096, S.seed(), S.run(3n, [G.ry(0.7, 0n), G.h(1n), G.cx(1n, 2n)], S.ket0(3n)))))
    IO.print("teleport RY(0.7)|0>, outcomes 00 01 10 11: " ++ tele(0.9, 0.9) ++ " " ++ tele(0.9, 0.1) ++ " " ++ tele(0.1, 0.9) ++ " " ++ tele(0.1, 0.1))

#|0.70710677+0i 0+0i 0+0i 0.70710677+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i
#|0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 1+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i 0+0i 0+0i
#|True False
#|norm of GHZ: 0.99999994
#|<Z0> on |0> and |1>: 1 -1
#|measure q0 of Bell, u = 0.9 then 0.1: 0 True, 1 True
#|4096 Bell shots, two bins within 3 sigma: True
#|00 2056
#|11 2040
#|4096 shots of RY(0.7)|0> (x) Bell(1, 2), expect 1807 1807 241 241:
#|000 1815
#|011 1807
#|100 260
#|111 214
#|teleport RY(0.7)|0>, outcomes 00 01 10 11: 00:True 01:True 10:True 11:True
