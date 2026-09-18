import Base

# The scalar module: complex F32 amplitudes and one-qubit gates. sim.bend uses
# only the names defined here, so an exact-arithmetic ring can replace this
# file behind the same interface.

# a complex amplitude re + im i
type C is Data:
  C{re: F32, im: F32}

def C.zero() -> C:
  C{0.0, 0.0}

def C.one() -> C:
  C{1.0, 0.0}

def C.add(x: C, y: C) -> C:
  match x y:
    case C{a, b} C{c, d}:
      C{F32.add(a, c), F32.add(b, d)}

def C.sub(x: C, y: C) -> C:
  match x y:
    case C{a, b} C{c, d}:
      C{F32.sub(a, c), F32.sub(b, d)}

def C.mul(x: C, y: C) -> C:
  match x y:
    case C{+a, +b} C{+c, +d}:
      C{F32.sub(F32.mul(a, c), F32.mul(b, d)), F32.add(F32.mul(a, d), F32.mul(b, c))}

# a real scale factor
def C.scale(+s: F32, x: C) -> C:
  match x:
    case C{a, b}:
      C{F32.mul(s, a), F32.mul(s, b)}

# the canonical form of an amplitude: every F32 pair already is one (the
# exact module reduces here)
def C.canon(x: C) -> C:
  x

# |x|^2
def C.norm2(x: C) -> F32:
  match x:
    case C{+a, +b}:
      F32.add(F32.mul(a, a), F32.mul(b, b))

# the amplitude rounded to three decimals, for pinned lines that must not
# depend on the last bit of a transcendental
def F32.round3(v: F32) -> F32:
  F32.div(F32.round(F32.mul(v, 1000.0)), 1000.0)

def C.round(x: C) -> C:
  match x:
    case C{a, b}:
      C{F32.round3(a), F32.round3(b)}

# printed as re+imi or re-imi, for example 0.70710677+0i; adding 0.0 turns a
# negative zero into a positive one, so a zero never prints with a sign
def C.show.im(neg: Bool, b: F32) -> String:
  match neg:
    case False{}:
      "+" ++ F32.show(b)
    case True{}:
      F32.show(b)

def C.show(x: C) -> String:
  match x:
    case C{a, b}:
      +im = F32.add(b, 0.0)
      F32.show(F32.add(a, 0.0)) ++ C.show.im(F32.is_lt(im, 0.0), im) ++ "i"

# a one-qubit gate, the matrix [[a, b], [c, d]]
type Gate is Data:
  Gate{a: C, b: C, c: C, d: C}

# the matrix-vector product (a x + b y, c x + d y): the leaf of every gate pass
def Gate.apply(g: Gate, +x: C, +y: C) -> C & C:
  match g:
    case Gate{a, b, c, d}:
      (C.add(C.mul(a, x), C.mul(b, y)), C.add(C.mul(c, x), C.mul(d, y)))

# 1/sqrt2, written once and multiplied, never divided
def rh() -> F32:
  0.70710677

def H() -> Gate:
  Gate{C{rh(), 0.0}, C{rh(), 0.0}, C{rh(), 0.0}, C{F32.neg(rh()), 0.0}}

def X() -> Gate:
  Gate{C.zero(), C.one(), C.one(), C.zero()}

# [[0, -i], [i, 0]]
def Y() -> Gate:
  Gate{C.zero(), C{0.0, F32.neg(1.0)}, C{0.0, 1.0}, C.zero()}

def Z() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{F32.neg(1.0), 0.0}}

# diag(1, i) and its inverse
def S() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{0.0, 1.0}}

def Sdg() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{0.0, F32.neg(1.0)}}

# diag(1, e^(i pi/4)) and its inverse
def T() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{rh(), rh()}}

def Tdg() -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{rh(), F32.neg(rh())}}

# the phase gate diag(1, e^(i phi))
def P(+phi: F32) -> Gate:
  Gate{C.one(), C.zero(), C.zero(), C{F32.cos(phi), F32.sin(phi)}}

# rotations by theta about X, Y and Z, built on the half angle
def RX(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, 0.0}, C{0.0, F32.neg(s)}, C{0.0, F32.neg(s)}, C{c, 0.0}}

def RY(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, 0.0}, C{F32.neg(s), 0.0}, C{s, 0.0}, C{c, 0.0}}

def RZ(theta: F32) -> Gate:
  +h = F32.mul(theta, 0.5)
  +c = F32.cos(h)
  +s = F32.sin(h)
  Gate{C{c, F32.neg(s)}, C.zero(), C.zero(), C{c, s}}

# a raw matrix [[a, b], [c, d]]
def U(a: C, b: C, c: C, d: C) -> Gate:
  Gate{a, b, c, d}
