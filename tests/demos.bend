import Base
import ../src/sim.bend as S
import ../src/circuits.bend as G

# Each demo prints one line, pinned below as a #| line. Amplitudes print root
# to leaf, so the bitstring 011 means q0=0, q1=1, q2=1. The identities compare
# two circuits on |0..0> to 1e-6 per amplitude.

# (|00> + |11>)/sqrt2
def bell() -> String:
  S.show(2n, S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n)))

# (|000> + |111>)/sqrt2
def ghz() -> String:
  S.show(3n, S.run(3n, [G.h(0n), G.cx(0n, 1n), G.cx(1n, 2n)], S.ket0(3n)))

# |110> -> |111>
def toffoli() -> String:
  S.show(3n, S.run(3n, [G.x(0n), G.x(1n), G.ccx(0n, 1n, 2n)], S.ket0(3n)))

# the control below the target: (|000> + |101>)/sqrt2
def below() -> String:
  S.show(3n, S.run(3n, [G.h(2n), G.cx(2n, 0n)], S.ket0(3n)))

# k T gates on |+> against |+>: True for k = 8, since T^8 = I, and False for
# the negative control k = 7
def tpow(k: Nat) -> String:
  plus = S.run(1n, [G.h(0n)], S.ket0(1n))
  back = S.run(1n, G.h(0n) <> List.replicate(S.Op, k, G.t(0n)), S.ket0(1n))
  Bool.show(S.near(1n, 1.0e-12, back, plus))

# Measurement and sampling
# ------------------------

# 2 rh^2 in F32, which shows the rounding of the 1/sqrt2 literal as 1 - 6e-8
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
# the collapsed, renormalized state equals the circuit want on |00>
def collapse.fin(want: List<&2, S.Op>, r: Bool & S.Q(2n)) -> String:
  (m, q) = r
  bit(m) ++ " " ++ Bool.show(S.near(2n, 1.0e-12, q, S.run(2n, want, S.ket0(2n))))

def collapse(u: F32, want: List<&2, S.Op>) -> String:
  collapse.fin(want, S.measure(2n, 0n, u, S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n))))

# 4096 shots of the Bell state from the default seed
def bell_hist() -> List<&2, S.Bin>:
  S.sample(2n, 4096, S.seed(), S.run(2n, [G.h(0n), G.cx(0n, 1n)], S.ket0(2n)))

# within 3 sigma of 2048, sigma = sqrt(4096 / 4) = 32
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
# and 2; the uniforms u0 and u1 drive the two measurements, and the fixes
# X^m1 then Z^m0 act on qubit 2

# the op when b holds
def when(b: Bool, op: S.Op) -> List<&2, S.Op>:
  match b:
    case True{}:
      [op]
    case False{}:
      Nil{}

def teleport.fix(+m0: Bool, r: Bool & S.Q(3n)) -> Bool & Bool & S.Q(3n):
  (+m1, q) = r
  (m0, m1, S.run(3n, List.append(&2, S.Op, when(m1, G.x(2n)), when(m0, G.z(2n))), q))

def teleport.m1(u1: F32, r: Bool & S.Q(3n)) -> Bool & Bool & S.Q(3n):
  (m0, q) = r
  teleport.fix(m0, S.measure(3n, 1n, u1, q))

def teleport(u0: F32, u1: F32) -> Bool & Bool & S.Q(3n):
  teleport.m1(u1, S.measure(3n, 0n, u0, S.run(3n, [G.ry(0.7, 0n), G.h(1n), G.cx(1n, 2n), G.cx(0n, 1n), G.h(0n)], S.ket0(3n))))

# the outcomes, and whether the final state is |m0 m1> (x) RY(0.7)|0>
def tele.fin(r: Bool & Bool & S.Q(3n)) -> String:
  (+m0, +m1, q) = r
  bit(m0) ++ bit(m1) ++ ":" ++ Bool.show(S.near(3n, 1.0e-12, q, S.run(3n, List.concat(&2, S.Op, [when(m0, G.x(0n)), when(m1, G.x(1n)), [G.ry(0.7, 2n)]]), S.ket0(3n))))

def tele(u0: F32, u1: F32) -> String:
  tele.fin(teleport(u0, u1))

# The QFT and Grover
# ------------------

# |001> then the QFT: (1/sqrt8) e^(2 pi i k/8) at index k
def qft_state() -> S.Q(3n):
  S.run(3n, List.append(&2, S.Op, [G.x(2n)], G.qft(3n)), S.ket0(3n))

# the same eight amplitudes written out, with 1/sqrt8 and 1/4
def r8() -> F32:
  0.35355339

def qft_want() -> S.Q(3n):
  (((S.C{r8(), 0.0}, S.C{0.25, 0.25}), (S.C{0.0, r8()}, S.C{F32.neg(0.25), 0.25})), ((S.C{F32.neg(r8()), 0.0}, S.C{F32.neg(0.25), F32.neg(0.25)}), (S.C{0.0, F32.neg(r8())}, S.C{0.25, F32.neg(0.25)})))

# Grover with |101> marked on 3 qubits: the probability of |101> after k
# iterations, exactly 1/8, 25/32 and 121/128 for k = 0, 1, 2
def grover_p(k: Nat) -> String:
  circuit = List.append(&2, S.Op, G.each(~G.h, 3n), List.concat(&2, S.Op, List.replicate(List<&2, S.Op>, k, G.grover(3n, [True{}, False{}, True{}]))))
  q = S.run(3n, circuit, S.ket0(3n))
  F32.show(S.F32.round3(S.norm2(3n, S.project(3n, 2n, True{}, S.project(3n, 1n, False{}, S.project(3n, 0n, True{}, q))))))

# Identities
# ----------

# both circuits on |0..0> reach the same state
def eq(+n: Nat, a: List<&2, S.Op>, b: List<&2, S.Op>) -> Bool:
  S.near(n, 1.0e-12, S.run(n, a, S.ket0(n)), S.run(n, b, S.ket0(n)))

def half_pi() -> F32:
  F32.mul(F32.pi(), 0.5)

# H with its matrix spelled out through U
def h_raw() -> S.Op:
  G.one(S.U(S.C{S.rh(), 0.0}, S.C{S.rh(), 0.0}, S.C{S.rh(), 0.0}, S.C{F32.neg(S.rh()), 0.0}), 0n)

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
    IO.print("QFT|001>: " ++ S.show3(3n, qft_state()))
    IO.print("QFT|001> = (1/sqrt8) e^(2 pi i k/8) to 1e-6: " ++ Bool.show(S.near(3n, 1.0e-12, qft_state(), qft_want())))
    IO.print("Grover |101> probability after 0, 1, 2 iterations: " ++ grover_p(0n) ++ " " ++ grover_p(1n) ++ " " ++ grover_p(2n))
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

#|0.70710677+0i 0+0i 0+0i 0.70710677+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i
#|0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 0+0i 1+0i
#|0.70710677+0i 0+0i 0+0i 0+0i 0+0i 0.70710677+0i 0+0i 0+0i
#|True False
#|norm of GHZ: 0.99999994
#|<Z0> on |0> and |1>: 1 -1
#|measure q0 of Bell, u = 0.9 then 0.1: 0 True, 1 True
#|4096 Bell shots, two bins within 3 sigma: True
#|00 2058
#|11 2038
#|4096 shots of RY(0.7)|0> (x) Bell(1, 2), expect 1807 1807 241 241:
#|000 1787
#|011 1815
#|100 239
#|111 255
#|teleport RY(0.7)|0>, outcomes 00 01 10 11: 00:True 01:True 10:True 11:True
#|QFT|001>: 0.354+0i 0.25+0.25i 0+0.354i -0.25+0.25i -0.354+0i -0.25-0.25i 0-0.354i 0.25-0.25i
#|QFT|001> = (1/sqrt8) e^(2 pi i k/8) to 1e-6: True
#|Grover |101> probability after 0, 1, 2 iterations: 0.125 0.781 0.945
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
