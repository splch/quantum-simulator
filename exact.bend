import Base

# The exact scalar module: amplitudes in D[w] = Z[w][1/sqrt2], w = e^(i pi/4).
# An amplitude is (a + b w + c w^2 + d w^3) / sqrt2^k with integers a b c d,
# kept in the canonical form where the numerator is not divisible by sqrt2
# (or is zero with k = 0) and every integer has one side zero. The Clifford+T
# gates need only addition, negation, halving, a parity test and the
# rotation that multiplies by w, so their laws in PROOF_exact.bend hold
# structurally. sim.bend and circuits.bend use this module through the same
# names as amp.bend; gates with an angle have no exact form and are absent.

# Int
# ---
# a difference of two Nats, pos - neg; every operation is componentwise

type Int is Data:
  Int{pos: Nat, neg: Nat}

def Int.zero() -> Int:
  Int{0n, 0n}

def Int.one() -> Int:
  Int{1n, 0n}

def Int.add(x: Int, y: Int) -> Int:
  match x y:
    case Int{a, b} Int{c, d}:
      Int{Nat.add(a, c), Nat.add(b, d)}

def Int.neg(x: Int) -> Int:
  match x:
    case Int{a, b}:
      Int{b, a}

def Int.sub(x: Int, y: Int) -> Int:
  Int.add(x, Int.neg(y))

def Int.mul(x: Int, y: Int) -> Int:
  match x y:
    case Int{+a, +b} Int{+c, +d}:
      Int{Nat.add(Nat.mul(a, c), Nat.mul(b, d)), Nat.add(Nat.mul(a, d), Nat.mul(b, c))}

# the sign and magnitude as an Int
def Int.of(neg: Bool, m: Nat) -> Int:
  match neg:
    case False{}:
      Int{m, 0n}
    case True{}:
      Int{0n, m}

# the canonical form: the smaller side becomes zero
def Int.norm.at(ge: Bool, a: Nat, b: Nat) -> Int:
  match ge:
    case False{}:
      Int{0n, Nat.sub(b, a)}
    case True{}:
      Int{Nat.sub(a, b), 0n}

def Int.norm(x: Int) -> Int:
  match x:
    case Int{+a, +b}:
      Int.norm.at(Nat.is_ge(a, b), a, b)

# x is even when both sides have the same parity
def Int.even(x: Int) -> Bool:
  match x:
    case Int{a, b}:
      Nat.is_eq(Nat.mod(a, 2n), Nat.mod(b, 2n))

# x / 2 for an even x: halving both sides, rounding down, halves the difference
def Int.half(x: Int) -> Int:
  match x:
    case Int{a, b}:
      Int{Nat.div(a, 2n), Nat.div(b, 2n)}

def Int.to_f32(x: Int) -> F32:
  match x:
    case Int{a, b}:
      F32.sub(F32.from_nat(a), F32.from_nat(b))

def Int.show.at(ge: Bool, a: Nat, b: Nat) -> String:
  match ge:
    case False{}:
      "-" ++ Nat.show(Nat.sub(b, a))
    case True{}:
      Nat.show(Nat.sub(a, b))

def Int.show(x: Int) -> String:
  match x:
    case Int{+a, +b}:
      Int.show.at(Nat.is_ge(a, b), a, b)

# C
# -
# (a + b w + c w^2 + d w^3) / sqrt2^k

type C is Data:
  C{a: Int, b: Int, c: Int, d: Int, k: Nat}

def C.zero() -> C:
  C{Int.zero(), Int.zero(), Int.zero(), Int.zero(), 0n}

def C.one() -> C:
  C{Int.one(), Int.zero(), Int.zero(), Int.zero(), 0n}

def C.k(x: C) -> Nat:
  match x:
    case C{a, b, c, d, k}:
      k

# times w: w (a + b w + c w^2 + d w^3) = -d + a w + b w^2 + c w^3, since w^4 = -1
def C.rot(x: C) -> C:
  match x:
    case C{a, b, c, d, k}:
      C{Int.neg(d), a, b, c, k}

def C.rot2(x: C) -> C:
  C.rot(C.rot(x))

def C.rot6(x: C) -> C:
  C.rot2(C.rot2(C.rot2(x)))

def C.rot7(x: C) -> C:
  C.rot(C.rot6(x))

def C.neg(x: C) -> C:
  match x:
    case C{a, b, c, d, k}:
      C{Int.neg(a), Int.neg(b), Int.neg(c), Int.neg(d), k}

# the same value over sqrt2^(k+1): the numerator times sqrt2 = w - w^3
def C.up(x: C) -> C:
  match x:
    case C{+a, +b, +c, +d, k}:
      C{Int.sub(b, d), Int.add(a, c), Int.add(b, d), Int.sub(c, a), 1n+k}

# x over sqrt2^(k+e)
def C.lift(e: Nat, x: C) -> C:
  match e:
    case 0n:
      x
    case 1n+f:
      C.lift(f, C.up(x))

# x and y over one denominator, added componentwise
def C.add.at(x: C, y: C) -> C:
  match x y:
    case C{a1, b1, c1, d1, k1} C{a2, b2, c2, d2, k2}:
      C{Int.add(a1, a2), Int.add(b1, b2), Int.add(c1, c2), Int.add(d1, d2), k1}

def C.add(+x: C, +y: C) -> C:
  C.add.at(C.lift(Nat.sub(C.k(y), C.k(x)), x), C.lift(Nat.sub(C.k(x), C.k(y)), y))

def C.sub(x: C, y: C) -> C:
  C.add(x, C.neg(y))

# the value over sqrt2^(k+1), which divides it by sqrt2
def C.raise(x: C) -> C:
  match x:
    case C{a, b, c, d, k}:
      C{a, b, c, d, 1n+k}

# Divide the numerator by sqrt2 while it divides and k > 0, then put every
# integer in canonical form: the least denominator, with zero as k = 0. The
# numerator divides by sqrt2 exactly when a - c and b - d are even, and then
# (a + b w + c w^2 + d w^3) / sqrt2 = (b-d)/2 + (a+c)/2 w + (b+d)/2 w^2 + (c-a)/2 w^3.
def C.reduce.fin(k: Nat, a: Int, b: Int, c: Int, d: Int) -> C:
  C{Int.norm(a), Int.norm(b), Int.norm(c), Int.norm(d), k}

def C.reduce.go(k: Nat, ok: Bool, +a: Int, +b: Int, +c: Int, +d: Int) -> C:
  match k ok:
    case 0n _:
      C.reduce.fin(0n, a, b, c, d)
    case 1n+j False{}:
      C.reduce.fin(1n+j, a, b, c, d)
    case 1n+j True{}:
      +a2 = Int.half(Int.sub(b, d))
      +b2 = Int.half(Int.add(a, c))
      +c2 = Int.half(Int.add(b, d))
      +d2 = Int.half(Int.sub(c, a))
      C.reduce.go(j, Int.even(Int.sub(a2, c2)) && Int.even(Int.sub(b2, d2)), a2, b2, c2, d2)

def C.reduce(x: C) -> C:
  match x:
    case C{+a, +b, +c, +d, k}:
      C.reduce.go(k, Int.even(Int.sub(a, c)) && Int.even(Int.sub(b, d)), a, b, c, d)

# the product over sqrt2^(k1+k2): (a1 + b1 w + c1 w^2 + d1 w^3)(a2 + b2 w + c2 w^2 + d2 w^3)
# with w^4 = -1; not reduced, see C.canon
def C.mul(x: C, y: C) -> C:
  match x y:
    case C{+a1, +b1, +c1, +d1, k1} C{+a2, +b2, +c2, +d2, k2}:
      C{Int.sub(Int.sub(Int.sub(Int.mul(a1, a2), Int.mul(b1, d2)), Int.mul(c1, c2)), Int.mul(d1, b2)), Int.sub(Int.sub(Int.add(Int.mul(a1, b2), Int.mul(b1, a2)), Int.mul(c1, d2)), Int.mul(d1, c2)), Int.sub(Int.add(Int.add(Int.mul(a1, c2), Int.mul(b1, b2)), Int.mul(c1, a2)), Int.mul(d1, d2)), Int.add(Int.add(Int.add(Int.mul(a1, d2), Int.mul(b1, c2)), Int.mul(c1, b2)), Int.mul(d1, a2)), Nat.add(k1, k2)}

# the canonical form, for the results of a matrix-vector product
def C.canon(x: C) -> C:
  C.reduce(x)

# H: ((x + y)/sqrt2, (x - y)/sqrt2), the butterfly with the denominator
# raised, each result reduced
def C.hadamard(+x: C, +y: C) -> C & C:
  (C.reduce(C.raise(C.add(x, y))), C.reduce(C.raise(C.sub(x, y))))

# |x|^2 as an F32: |a + b w + c w^2 + d w^3|^2 = a^2 + b^2 + c^2 + d^2 + (ab + bc + cd - da) sqrt2
def C.norm2(x: C) -> F32:
  match x:
    case C{+a, +b, +c, +d, k}:
      m = Int.to_f32(Int.add(Int.add(Int.mul(a, a), Int.mul(b, b)), Int.add(Int.mul(c, c), Int.mul(d, d))))
      n = Int.to_f32(Int.sub(Int.add(Int.add(Int.mul(a, b), Int.mul(b, c)), Int.mul(c, d)), Int.mul(d, a)))
      F32.div(F32.add(m, F32.mul(n, 1.4142135)), F32.pow(2.0, F32.from_nat(k)))

# Exact multiplication by an F32, which is an integer m times a power of two
# read off its bits: the product is exact over a larger denominator. The
# integers grow by m, so this serves a renormalization or two, not a loop.
def C.scale.by(+m: Int, k: Nat, x: C) -> C:
  match x:
    case C{a, b, c, d, kx}:
      C.reduce(C{Int.mul(m, a), Int.mul(m, b), Int.mul(m, c), Int.mul(m, d), Nat.add(k, kx)})

# m 2^(e-150): shifted up when e >= 150, else over sqrt2^(2 (150 - e))
def C.scale.exp(neg: Bool, m: Nat, up: Bool, e: Nat, x: C) -> C:
  match up:
    case True{}:
      C.scale.by(Int.of(neg, Nat.mul(m, Nat.pow(2n, Nat.sub(e, 150n)))), 0n, x)
    case False{}:
      C.scale.by(Int.of(neg, m), Nat.mul(2n, Nat.sub(150n, e)), x)

# the IEEE fields: a zero exponent means the subnormal f 2^-149, or zero
def C.scale.fields(neg: Bool, small: Bool, +e: Nat, f: Nat, x: C) -> C:
  match small:
    case True{}:
      C.scale.by(Int.of(neg, f), 298n, x)
    case False{}:
      C.scale.exp(neg, Nat.add(U32.to_nat(8388608), f), Nat.is_ge(e, 150n), e, x)

def C.scale.bits(+w: U32, x: C) -> C:
  +e = ((w >> 23n) .&. 255 : U32)
  C.scale.fields(U32.is_ge(w, 2147483648), U32.is_eq(e, 0), U32.to_nat(e), U32.to_nat((w .&. 8388607 : U32)), x)

def C.scale(s: F32, x: C) -> C:
  C.scale.bits(F32.bits(s), x)

# an exact amplitude needs no rounding for display
def C.round(x: C) -> C:
  x

# printed as [a b c d] over rt2^k, for example [1 0 0 0]/rt2^1 for 1/sqrt2
def C.show.den(k: Nat) -> String:
  match k:
    case 0n:
      ""
    case 1n+j:
      "/rt2^" ++ Nat.show(1n+j)

def C.show(x: C) -> String:
  match x:
    case C{a, b, c, d, k}:
      "[" ++ Int.show(a) ++ " " ++ Int.show(b) ++ " " ++ Int.show(c) ++ " " ++ Int.show(d) ++ "]" ++ C.show.den(k)

# Gate
# ----
# the Clifford+T gates as operations: X swaps the pair, Z negates, S T Sdg
# Tdg rotate the |1> amplitude by w^2, w, w^6, w^7, Y is (-i y, i x), and H
# is the butterfly

type Gate is Data:
  Gx{}
  Gy{}
  Gz{}
  Gh{}
  Gs{}
  Gsdg{}
  Gt{}
  Gtdg{}

def X() -> Gate:
  Gx{}

def Y() -> Gate:
  Gy{}

def Z() -> Gate:
  Gz{}

def H() -> Gate:
  Gh{}

def S() -> Gate:
  Gs{}

def Sdg() -> Gate:
  Gsdg{}

def T() -> Gate:
  Gt{}

def Tdg() -> Gate:
  Gtdg{}

# the gate on the amplitude pair (x, y)
def Gate.apply(g: Gate, x: C, y: C) -> C & C:
  match g:
    case Gx{}:
      (y, x)
    case Gy{}:
      (C.rot6(y), C.rot2(x))
    case Gz{}:
      (x, C.neg(y))
    case Gh{}:
      C.hadamard(x, y)
    case Gs{}:
      (x, C.rot2(y))
    case Gsdg{}:
      (x, C.rot6(y))
    case Gt{}:
      (x, C.rot(y))
    case Gtdg{}:
      (x, C.rot7(y))
