import Base

# xorshift32, Marsaglia (a,b,c) = (13,17,5), T = (I+L13)(I+R17)(I+L5)
# NOTE: every binding reused twice must be `+x =` (affine let otherwise)
def xs32(+x: U32) -> U32:
  +a = (x .^. (x << 13n) : U32)
  +b = (a .^. (a >> 17n) : U32)
  (b .^. (b << 5n) : U32)

# hash-prospector 2-round finalizer [16 0x21f0aaad 15 0xd35a2d97 15]
# decimal because Bend 2 has no hex literals
def mix32(+x: U32) -> U32:
  +a = (x .^. (x >> 16n) : U32)
  +b = (a * 569420461 : U32)
  +c = (b .^. (b >> 15n) : U32)
  +d = (c * 3545902487 : U32)
  (d .^. (d >> 15n) : U32)

# U32 -> F32 uniform in [0,1): top 24 bits * 2^-24 (both steps exact)
def unif(x: U32) -> F32:
  F32.mul(U32.to_f32((x >> 8n : U32)), 5.9604645e-8)

def main() -> IO(Unit):
  +s1 = xs32(2463534242)
  +s2 = xs32(s1)
  +s3 = xs32(s2)
  wrap = (4294967295 * 3 : U32)
  do IO<Unit>:
    IO.print("xs32 chain: " ++ U32.show(s1) ++ " " ++ U32.show(s2) ++ " " ++ U32.show(s3))
    IO.print("mix32(0)=" ++ U32.show(mix32(0)) ++ " mix32(1)=" ++ U32.show(mix32(1)))
    IO.print("wrap 4294967295*3 = " ++ U32.show(wrap) ++ " (expect 4294967293)")
    IO.print("unif(0)=" ++ F32.show(unif(0)) ++ " unif(max)=" ++ F32.show(unif(4294967295)))
    IO.print("sqrt2=" ++ F32.show(F32.sqrt(2.0)) ++ " 1/sqrt2=" ++ F32.show(F32.div(1.0, F32.sqrt(2.0))))
    IO.print("sin(pi/4)=" ++ F32.show(F32.sin(F32.div(F32.pi(), 4.0))))
