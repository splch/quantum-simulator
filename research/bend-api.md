# Bend 2.0.5 API survey for the quantum simulator

Source: `bend2/base.bend` of `bendlang/bend` at 2.0.5 (shallow clone, 2026-09-17). Every block below is verbatim: `def` lines are the signature up to the trailing `:` (bodies dropped); `law` and `type` blocks are complete (a `law` with no `def` in Base is a primitive implemented by the runtime). Section "Idioms" quotes GUIDE.md, tests and demos.

## Kinds, quantities, pairs (facts that matter for the design)

- `Type = Kind(&1)` (affine, one owner), `Data = Kind(&2)` (copiable). A `+x` binder or `+x = v` let needs a `Data`-kinded type.
- `A & B` is `Pair(A, B) = Sigma<&1, &1, A, _ => B>`, so **a pair is always `Type`-kinded**, even when both sides are `Data`. A copiable pair must be spelled `Sigma<&2, &2, A, _ => B>` (verified: `def Q(n: Nat) -> Data` with that branch checks and `+q: Q(n)` may be used twice). The tuple literal `(a, b)` and the destructuring let `(a, b) = p` work for both.
- A dependent type family is an ordinary def: `def Word(n): match n: case 0n: Word.Nil case 1n+p: Word.Con<p>` fills `law Word: for n: Nat; Data`. Base's `Word(n)` is exactly the `Q(n)` pattern with kind `Data`.
- `F32.show(+a: F32)` formatting (run here on the JS backend): `0.70710677 | 1 | -0 | -0.70710677 | 0 | 1.4142135 | 0.70710677` for `0.70710677, 1.0, F32.neg(0.0), F32.neg(0.70710677), 0.0, F32.sqrt(2.0), F32.div(1.0, F32.sqrt(2.0))`. Six to eight significant digits, no trailing `.0`, e-notation for small magnitudes (`9.536741e-7`, `5.960463e-8` printed by the native binary). `tests/run/float_printing.bend` pins `2 100.25 0.33333334 0.0009765625 123456`.
- Float literals exist (`1.5`, `0.0`, `0.70710677`); a negative literal was not tried, `F32.neg(x)` works. The nbody bench's comment "no float literal syntax in Bend4" is stale.

## Signatures by namespace

### Pair / Sigma / Either / Exists / Or

```python
type Either<a, b, -A: Kind(a), -B: Kind(b)> is Kind(a <&> b):
  Inl{value: A}
  Inr{value: B}

type Sigma<a, b, -A: Kind(a), -B: @-x: A -> Kind(b)> is Kind(a <&> b):
  Tuple{fst: A, snd: B(fst)}

law Pair:
  for -A: Type
  for -B: Type
  Type

def Pair(A, B):

def Exists(-A: Type, -B: @-x: A -> Type) -> Type:

def Or(-A: Type, -B: Type) -> Type:

def Pair.fst(-A: Type, -B: Type, p: A & B) -> A:

def Pair.snd(-A: Type, -B: Type, p: A & B) -> B:

```

### Empty / Unit / Bool / Cmp

```python
type Empty is Data:

type Unit is Data:
  Unit{}

type Bool is Data:
  False{}
  True{}

type Cmp is Data:
  LT{}
  EQ{}
  GT{}

def Empty.absurd(-A: Type, e: Empty) -> A:

def Bool.not(b: Bool) -> Bool:

def Bool.and(a: Bool, b: Bool) -> Bool:

def Bool.or(a: Bool, b: Bool) -> Bool:

def Bool.xor(a: Bool, b: Bool) -> Bool:

def Bool.cmp(a: Bool, b: Bool) -> Cmp:

def Bool.full_add(a: Bool, b: Bool, c: Bool) -> Bool & Bool:

def Bool.pick(-A: Type, c: Bool, a: A, b: A) -> A:

def Bool.to_u32(b: Bool) -> U32:

def Cmp.is_lt(c: Cmp) -> Bool:

def Cmp.is_eq(c: Cmp) -> Bool:

def Cmp.is_gt(c: Cmp) -> Bool:

def Cmp.is_le(c: Cmp) -> Bool:

def Cmp.is_ge(c: Cmp) -> Bool:

def Bool.show(b: Bool) -> String:

```

### Equal

```python
law Equal.cong:
  for -A: Type
  for -B: Type
  for -f: A -> B
  for -a: A
  for -b: A
  for  e: {a == b : A}
  {f(a) == f(b) : B}

def Equal.cong(A, B, f, a, b, e):

law Equal.sym:
  for -A: Type
  for -a: A
  for -b: A
  for  e: {a == b : A}
  {b == a : A}

def Equal.sym(A, a, b, e):

law Equal.trans:
  for -A : Type
  for -a : A
  for -b : A
  for -c : A
  for ab : {a == b : A}
  for bc : {b == c : A}
  {a == c : A}

def Equal.trans(A, a, b, c, ab, bc):

```

### Nat

```python
type Nat is Data:
  Zero{}
  Succ{pred: Nat}

def Nat.double(n: Nat) -> Nat:

def Nat.add(a: Nat, b: Nat) -> Nat:

def Nat.sub(a: Nat, b: Nat) -> Nat:

def Nat.mul(a: Nat, +b: Nat) -> Nat:

def Nat.divmod.go(n: Nat, m: Nat, d: Nat, r: Nat) -> Nat & Nat:

def Nat.divmod(a: Nat, b: Nat) -> Nat & Nat:

def Nat.cmp(a: Nat, b: Nat) -> Cmp:

def Nat.is_lt(a: Nat, b: Nat) -> Bool:

def Nat.is_eq(a: Nat, b: Nat) -> Bool:

def Nat.is_ne(a: Nat, b: Nat) -> Bool:

def Nat.is_le(a: Nat, b: Nat) -> Bool:

def Nat.is_gt(a: Nat, b: Nat) -> Bool:

def Nat.is_ge(a: Nat, b: Nat) -> Bool:

def Nat.min(+a: Nat, +b: Nat) -> Nat:

def Nat.max(+a: Nat, +b: Nat) -> Nat:

def Nat.div.fin(qr: Nat & Nat) -> Nat:

def Nat.div(a: Nat, b: Nat) -> Nat:

def Nat.mod.fin(qr: Nat & Nat) -> Nat:

def Nat.mod(a: Nat, b: Nat) -> Nat:

def Nat.pow(+a: Nat, b: Nat) -> Nat:

def Nat.show.put(qr: Nat & Nat) -> Char & Nat:

law Nat.show.go:
  for f   : Nat
  for n   : Nat
  for acc : String
  String

def Nat.show.fin(g: Nat, acc: String, dq: Char & Nat) -> String:

def Nat.show.go(f, n, acc):

def Nat.show(n: Nat) -> String:

law Nat.read.go:
  for s   : String
  for +acc : Nat
  Maybe<&2, Nat>

def Nat.read.max() -> Nat:

def Nat.read.fit(acc: Nat, qr: Nat & Nat) -> Bool:

def Nat.read.if(t: String, acc: Nat, d: U32, ok: Bool) -> Maybe<&2, Nat>:

def Nat.read.go(s, acc):

def Nat.read(s: String) -> Maybe<&2, Nat>:

```

### U32 (bit ops for a xorshift PRNG: and or xor not shl shr shln shrn mul)

```python
type U32 is Data:
  U32{data: Word(32n)}

def U32.inc(a: U32) -> U32:

def U32.add(a: U32, b: U32) -> U32:

law U32.add_comm:
  for a: U32
  for b: U32
  {U32.add(a, b) == U32.add(b, a) : U32}

def U32.add_comm(a, b):

def U32.sub(a: U32, b: U32) -> U32:

def U32.mul(a: U32, b: U32) -> U32:

def U32.not(a: U32) -> U32:

def U32.and(a: U32, b: U32) -> U32:

def U32.or(a: U32, b: U32) -> U32:

def U32.xor(a: U32, b: U32) -> U32:

def U32.shl(a: U32) -> U32:

def U32.shr(a: U32) -> U32:

def U32.shln(a: U32, n: Nat) -> U32:

def U32.shrn(a: U32, n: Nat) -> U32:

def U32.cmp(a: U32, b: U32) -> Cmp:

def U32.is_eq(a: U32, b: U32) -> Bool:

def U32.is_ne(a: U32, b: U32) -> Bool:

def U32.is_lt(a: U32, b: U32) -> Bool:

def U32.is_le(a: U32, b: U32) -> Bool:

def U32.is_gt(a: U32, b: U32) -> Bool:

def U32.is_ge(a: U32, b: U32) -> Bool:

def U32.is_zero(a: U32) -> Bool:

def U32.to_nat(a: U32) -> Nat:

def U32.from_nat(n: Nat) -> U32:

def U32.divmod.go.fin(-p: Nat, q: Word(p), s: U32, b: U32, g: Bool) ->
  Word(1n+p) & U32:

def U32.divmod.go.shl(-p: Nat, q: Word(p), +b: U32, ts: Bool & Word(32n)) ->
  Word(1n+p) & U32:

def U32.divmod.go.rec(-p: Nat, a0: Bool, +b: U32, qr: Word(p) & U32) ->
  Word(1n+p) & U32:

def U32.divmod.go(m: Nat, a: Word(m), +b: U32) -> Word(m) & U32:

def U32.div.fin(qr: Word(32n) & U32) -> U32:

def U32.div.if(aw: Word(32n), b: U32, z: Bool) -> U32:

def U32.div(a: U32, +b: U32) -> U32:

def U32.mod.fin(qr: Word(32n) & U32) -> U32:

def U32.mod.if(aw: Word(32n), b: U32, z: Bool) -> U32:

def U32.mod(a: U32, +b: U32) -> U32:

def U32.min(+a: U32, +b: U32) -> U32:

def U32.max(+a: U32, +b: U32) -> U32:

def U32.clamp(x: U32, lo: U32, hi: U32) -> U32:

def U32.pow(+a: U32, n: Nat) -> U32:

def U32.is_even(a: U32) -> Bool:

law U32.to_f32:
  for a: U32
  F32

law U32.show.go:
  for f   : Nat
  for +n  : U32
  for acc : String
  String

def U32.show.fin(g: Nat, acc: String, +n: U32, z: Bool) -> String:

def U32.show.go(f, n, acc):

def U32.show.if(a: U32, z: Bool) -> String:

def U32.show(a: U32) -> String:

law U32.read.go:
  for s   : String
  for +acc : U32
  Maybe<&2, U32>

def U32.read.if(t: String, n: U32, ok: Bool) -> Maybe<&2, U32>:

def U32.read.go(s, acc):

def U32.read(s: String) -> Maybe<&2, U32>:

```

### F32 (all primitives are laws filled by the runtime)

```python
type F32 is Data:
  F32{data: Word(32n)}

law F32.to_u32:
  for a: F32
  U32

law F32.add:
  for a: F32
  for b: F32
  F32

law F32.sub:
  for a: F32
  for b: F32
  F32

law F32.mul:
  for a: F32
  for b: F32
  F32

law F32.div:
  for a: F32
  for b: F32
  F32

law F32.mod:
  for a: F32
  for b: F32
  F32

law F32.pow:
  for a: F32
  for b: F32
  F32

law F32.atan2:
  for a: F32
  for b: F32
  F32

law F32.neg:
  for a: F32
  F32

law F32.abs:
  for a: F32
  F32

law F32.sqrt:
  for a: F32
  F32

law F32.exp:
  for a: F32
  F32

law F32.log:
  for a: F32
  F32

law F32.log2:
  for a: F32
  F32

law F32.log10:
  for a: F32
  F32

law F32.sin:
  for a: F32
  F32

law F32.cos:
  for a: F32
  F32

law F32.tan:
  for a: F32
  F32

law F32.asin:
  for a: F32
  F32

law F32.acos:
  for a: F32
  F32

law F32.atan:
  for a: F32
  F32

law F32.sinh:
  for a: F32
  F32

law F32.cosh:
  for a: F32
  F32

law F32.tanh:
  for a: F32
  F32

law F32.floor:
  for a: F32
  F32

law F32.ceil:
  for a: F32
  F32

law F32.trunc:
  for a: F32
  F32

law F32.is_eq:
  for a: F32
  for b: F32
  Bool

law F32.is_ne:
  for a: F32
  for b: F32
  Bool

law F32.is_lt:
  for a: F32
  for b: F32
  Bool

law F32.is_le:
  for a: F32
  for b: F32
  Bool

law F32.is_gt:
  for a: F32
  for b: F32
  Bool

law F32.is_ge:
  for a: F32
  for b: F32
  Bool

law F32.show:
  for +a: F32
  String

law F32.bits:
  for a: F32
  U32

law F32.read:
  for s: String
  Maybe<&2, F32>

def F32.min(+a: F32, +b: F32) -> F32:

def F32.max(+a: F32, +b: F32) -> F32:

def F32.clamp(x: F32, lo: F32, hi: F32) -> F32:

def F32.lerp(+a: F32, b: F32, t: F32) -> F32:

def F32.square(+a: F32) -> F32:

def F32.hypot(+x: F32, +y: F32) -> F32:

def F32.round(a: F32) -> F32:

def F32.pi() -> F32:

def F32.from_nat(n: Nat) -> F32:

def F32.to_nat(a: F32) -> Nat:

```

### Word (the bit-vector family behind U32/F32)

```python
law Word:
  for n: Nat
  Data

type Word.Nil is Data:
  WNil{}

type Word.Con<-p: Nat> is Data:
  WCon{head: Bool, tail: Word(p)}

def Word(n):

def Word.zero(n: Nat) -> Word(n):

def Word.not(n: Nat, w: Word(n)) -> Word(n):

def Word.and(n: Nat, a: Word(n), b: Word(n)) -> Word(n):

def Word.or(n: Nat, a: Word(n), b: Word(n)) -> Word(n):

def Word.xor(n: Nat, a: Word(n), b: Word(n)) -> Word(n):

def Word.shl.put(n: Nat, c: Bool, w: Word(n)) -> Word(n):

def Word.shl(n: Nat, w: Word(n)) -> Word(n):

def Word.shl.out.con(-p: Nat, c: Bool, r: Bool & Word(p)) -> Bool & Word(1n+p):

def Word.shl.out(n: Nat, c: Bool, w: Word(n)) -> Bool & Word(n):

def Word.shr.pad(n: Nat, w: Word(n)) -> Word(1n+n):

def Word.shr(n: Nat, w: Word(n)) -> Word(n):

def Word.cmp.fin(ab: Bool, bb: Bool, t: Cmp) -> Cmp:

def Word.cmp(n: Nat, a: Word(n), b: Word(n)) -> Cmp:

def Word.inc(n: Nat, w: Word(n)) -> Word(n):

law Word.adc:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for f: Bool
  for c: Bool
  Word(n)

def Word.adc.con(p: Nat, at: Word(p), bt: Word(p), f: Bool, sk: Bool & Bool) ->
  Word(1n+p):

def Word.adc(n, a, b, f, c):

def Word.add(n: Nat, a: Word(n), b: Word(n)) -> Word(n):

def Word.sub(n: Nat, a: Word(n), b: Word(n)) -> Word(n):

law Word.add_comm.arm:
  for p  : Nat
  for -h : Bool
  for at : Word(p)
  for bt : Word(p)
  for k  : Bool
  {WCon{h, Word.adc(p, at, bt, False{}, k)}
    == WCon{h, Word.adc(p, bt, at, False{}, k)} : Word.Con<p>}

law Word.add_comm.go:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for c: Bool
  {Word.adc(n, a, b, False{}, c) == Word.adc(n, b, a, False{}, c) : Word(n)}

def Word.add_comm.arm(p, h, at, bt, k):

def Word.add_comm.go(n, a, b, c):

law Word.add_comm:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  {Word.add(n, a, b) == Word.add(n, b, a) : Word(n)}

def Word.add_comm(n, a, b):

def Word.to_nat(n: Nat, w: Word(n)) -> Nat:

def Word.mul.go(+n: Nat, m: Nat, a: Word(m), +b: Word(n), acc: Word(n)) ->
  Word(n):

def Word.mul(+n: Nat, a: Word(n), b: Word(n)) -> Word(n):

```

### Char

```python
type Char is Data:
  Chr{code: U32}

def Char.cmp(a: Char, b: Char) -> (Char & Char) & Cmp:

def Char.to_u32(c: Char) -> U32:

def Char.from_u32(x: U32) -> Char:

def Char.is_eq(a: Char, b: Char) -> Bool:

def Char.is_digit(c: Char) -> Bool:

def Char.is_upper(c: Char) -> Bool:

def Char.is_lower(c: Char) -> Bool:

def Char.is_alpha(+c: Char) -> Bool:

def Char.is_space(c: Char) -> Bool:

def Char.to_upper(+c: Char) -> Char:

def Char.to_lower(+c: Char) -> Char:

def Char.show(c: Char) -> String:

```

### String

```python
type String is Data:
  SNil{}
  SCon{head: Char, tail: String}

def String.append(a: String, b: String) -> String:

def String.cmp.rec(h1b: Char, h2b: Char, rr: (String & String) & Cmp) ->
  (String & String) & Cmp:

law String.cmp:
  for a: String
  for b: String
  (String & String) & Cmp

def String.cmp.fin(t1: String, t2: String, hc: (Char & Char) & Cmp) ->
  (String & String) & Cmp:

def String.cmp(a, b):

def String.eq.fin(r: (String & String) & Cmp) -> Bool:

def String.eq(a: String, b: String) -> Bool:

def String.length(s: String) -> Nat:

def String.is_empty(s: String) -> Bool:

def String.reverse.go(s: String, acc: String) -> String:

def String.reverse(s: String) -> String:

def String.order.fin(r: (String & String) & Cmp) -> Cmp:

def String.order(a: String, b: String) -> Cmp:

def String.is_lt(a: String, b: String) -> Bool:

def String.is_le(a: String, b: String) -> Bool:

def String.is_gt(a: String, b: String) -> Bool:

def String.is_ge(a: String, b: String) -> Bool:

law String.starts_with:
  for s: String
  for p: String
  Bool

def String.starts_with.if(t: String, pt: String, same: Bool) -> Bool:

def String.starts_with(s, p):

def String.ends_with(s: String, p: String) -> Bool:

law String.contains:
  for +s: String
  for +p: String
  Bool

def String.contains.if(t: String, p: String, here: Bool) -> Bool:

def String.contains(s, p):

def String.take(s: String, n: Nat) -> String:

def String.drop(s: String, n: Nat) -> String:

def String.get(s: String, n: Nat) -> Maybe<&2, Char>:

def String.to_list(s: String) -> List<&2, Char>:

def String.from_list(cs: List<&2, Char>) -> String:

def String.concat(xs: List<&2, String>) -> String:

def String.join.go(xs: List<&2, String>, h: String, +sep: String) -> String:

def String.join(xs: List<&2, String>, +sep: String) -> String:

def String.split.push(c: Char, ps: List<&2, String>) -> List<&2, String>:

def String.split.fin(c: Char, r: List<&2, String>, cut: Bool) ->
  List<&2, String>:

def String.split(s: String, +sep: Char) -> List<&2, String>:

def String.lines(s: String) -> List<&2, String>:

def String.repeat(+s: String, n: Nat) -> String:

def String.to_upper(s: String) -> String:

def String.to_lower(s: String) -> String:

law String.trim_start:
  for s: String
  String

def String.trim_start.if(h: Char, t: String, space: Bool) -> String:

def String.trim_start(s):

def String.trim_end(s: String) -> String:

def String.trim(s: String) -> String:

```

### List (constructors Nil{} and Con{head, tail}; cons pattern is h <> t)

```python
type List<a, -A: Kind(a)> is Kind(a):
  Nil{}
  Con{head: A, tail: List<a, A>}

def List.map(~A: Type, ~B: Type, ~f: A -> B, xs: List<A>) -> List<B>:

def List.length(a, -A: Kind(a), xs: List<a, A>) -> Nat:

def List.append(a, -A: Kind(a), xs: List<a, A>, ys: List<a, A>) -> List<a, A>:

def List.concat(a, -A: Kind(a), xss: List<a, List<a, A>>) -> List<a, A>:

def List.reverse.go(a, -A: Kind(a), xs: List<a, A>, acc: List<a, A>) ->
  List<a, A>:

def List.reverse(a, -A: Kind(a), xs: List<a, A>) -> List<a, A>:

def List.is_empty(a, -A: Kind(a), xs: List<a, A>) -> Bool:

def List.head(a, -A: Kind(a), xs: List<a, A>) -> Maybe<a, A>:

def List.tail(a, -A: Kind(a), xs: List<a, A>) -> List<a, A>:

def List.last.go(a, -A: Kind(a), xs: List<a, A>, last: A) -> A:

def List.last(a, -A: Kind(a), xs: List<a, A>) -> Maybe<a, A>:

def List.get(a, -A: Kind(a), xs: List<a, A>, n: Nat) -> Maybe<a, A>:

def List.set(a, -A: Kind(a), xs: List<a, A>, n: Nat, x: A) -> List<a, A>:

def List.take(a, -A: Kind(a), xs: List<a, A>, n: Nat) -> List<a, A>:

def List.drop(a, -A: Kind(a), xs: List<a, A>, n: Nat) -> List<a, A>:

def List.zip(
  a, -A: Kind(a), b, -B: Kind(b), xs: List<a, A>, ys: List<b, B>
) -> List<&1, A & B>:

def List.range.go(+n: Nat, acc: List<&2, Nat>) -> List<&2, Nat>:

def List.range(n: Nat) -> List<&2, Nat>:

def List.replicate(-A: Data, n: Nat, +x: A) -> List<&2, A>:

def List.filter.put(-A: Data, h: A, r: List<&2, A>, keep: Bool) -> List<&2, A>:

def List.filter(~A: Data, ~f: A -> Bool, xs: List<&2, A>) -> List<&2, A>:

def List.foldl(
  ~a: Quant, ~A: Kind(a), ~B: Type, ~f: B -> A -> B, xs: List<a, A>, acc: B
) -> B:

def List.foldr(
  ~a: Quant, ~A: Kind(a), ~B: Type, ~f: A -> B -> B, xs: List<a, A>, z: B
) -> B:

def List.any(~a: Quant, ~A: Kind(a), ~f: A -> Bool, xs: List<a, A>) -> Bool:

def List.all(~a: Quant, ~A: Kind(a), ~f: A -> Bool, xs: List<a, A>) -> Bool:

def List.find.put(-A: Data, h: A, r: Maybe<&2, A>, hit: Bool) -> Maybe<&2, A>:

def List.find(~A: Data, ~f: A -> Bool, xs: List<&2, A>) -> Maybe<&2, A>:

def List.contains(
  ~A: Data, ~eq: A -> A -> Bool, xs: List<&2, A>, +x: A
) -> Bool:

def List.merge.step(
  -A: Data, acc: List<&2, A>, x: A, xt: List<&2, A>, y: A, yt: List<&2, A>,
  le: Bool
) -> List<&2, A> & List<&2, A> & List<&2, A>:

def List.merge.go(
  ~A: Data, ~le: A -> A -> Bool, fuel: Nat,
  st: List<&2, A> & List<&2, A> & List<&2, A>
) -> List<&2, A>:

def List.sort.runs(-A: Data, xs: List<&2, A>) -> List<&2, List<&2, A>>:

def List.sort.pass(
  ~A: Data, ~le: A -> A -> Bool, +n: Nat, runs: List<&2, List<&2, A>>
) -> List<&2, List<&2, A>>:

def List.sort.go(
  ~A: Data, ~le: A -> A -> Bool, fuel: Nat, +n: Nat, runs: List<&2, List<&2, A>>
) -> List<&2, A>:

def List.sort(~A: Data, ~le: A -> A -> Bool, +xs: List<&2, A>) -> List<&2, A>:

def List.for_each(
  ~a: Quant, ~A: Kind(a), ~f: A -> IO(Unit), xs: List<a, A>
) -> IO(Unit):

def List.show.go(~a: Quant, ~A: Kind(a), ~f: A -> String, xs: List<a, A>) ->
  String:

def List.show(~a: Quant, ~A: Kind(a), ~f: A -> String, xs: List<a, A>) ->
  String:

```

### Maybe / Result

```python
type Maybe<a, -A: Kind(a)> is Kind(a):
  None{}
  Some{value: A}

type Result<a, b, -E: Kind(a), -A: Kind(b)> is Kind(a <&> b):
  Fail{error: E}
  Done{value: A}

def Maybe.pure(a, -A: Kind(a), x: A) -> Maybe<a, A>:

def Maybe.bind(
  a, -A: Kind(a), -B: Kind(a), m: Maybe<a, A>, f: A -> Maybe<a, B>
) -> Maybe<a, B>:

def Maybe.default(a, -A: Kind(a), m: Maybe<a, A>, d: A) -> A:

def Maybe.is_some(a, -A: Kind(a), m: Maybe<a, A>) -> Bool:

def Maybe.is_none(a, -A: Kind(a), m: Maybe<a, A>) -> Bool:

def Maybe.map(
  a, -A: Kind(a), -B: Kind(a), f: A -> B, m: Maybe<a, A>
) -> Maybe<a, B>:

def Maybe.or(a, -A: Kind(a), m: Maybe<a, A>, n: Maybe<a, A>) -> Maybe<a, A>:

def Result.pure(a, b, -E: Kind(a), -A: Kind(b), x: A) -> Result<a, b, E, A>:

def Result.bind(
  a, b, -E: Kind(a), -A: Kind(b), -B: Kind(b), r: Result<a, b, E, A>,
  f: A -> Result<a, b, E, B>
) -> Result<a, b, E, B>:

def Result.default(
  a, b, -E: Kind(a), -A: Kind(b), r: Result<a, b, E, A>, d: A
) -> A:

def Result.is_done(
  a, b, -E: Kind(a), -A: Kind(b), r: Result<a, b, E, A>
) -> Bool:

def Result.is_fail(
  a, b, -E: Kind(a), -A: Kind(b), r: Result<a, b, E, A>
) -> Bool:

def Result.map(
  a, b, -E: Kind(a), -A: Kind(b), -B: Kind(b), f: A -> B,
  r: Result<a, b, E, A>
) -> Result<a, b, E, B>:

def Maybe.show(~a: Quant, ~A: Kind(a), ~f: A -> String, m: Maybe<a, A>) ->
  String:

```

### Map / Set (string keys only)

```python
type Map<a, -V: Kind(a)> is Kind(a):
  MTip{}
  MLeaf{key: String, val: V}
  MNode{pos: Nat, lo: Map<a, V>, hi: Map<a, V>}

def Map.bit.u(x: U32, k: Nat) -> Bool:

def Map.bit.chr(c: Char, off: Nat) -> Char & Bool:

def Map.bit.go.chr(t: String, r: Char & Bool) -> String & Bool:

def Map.bit.go.rec(c: Char, r: String & Bool) -> String & Bool:

def Map.bit.go(key: String, ci: Nat, off: Nat) -> String & Bool:

def Map.bit.at(key: String, co: Nat & Nat) -> String & Bool:

def Map.bit(key: String, pos: Nat) -> String & Bool:

law Map.msb.u:
  for n: Nat
  for +x: U32
  Nat

def Map.msb.u.if(p: Nat, x2: U32, z: Bool) -> Nat:

def Map.msb.u(n, x):

def Map.diff.chr(x: U32) -> Nat:

def Map.diff.step(x: Char, y: Char) -> Nat & Bool:

law Map.diff:
  for a: String
  for b: String
  Nat

def Map.diff.fin(xt: String, yt: String, rc: Nat & Bool) -> Nat:

def Map.diff(a, b):

def Map.new(a, -V: Kind(a)) -> Map<a, V>:

law Map.put:
  for -a  : Quant
  for -V  : Kind(a)
  for m   : Map<a, V>
  for key : String
  for x   : V
  Map<a, V>

def Map.put.bit(
  a, -V: Kind(a), x: V, p2: Nat, lo: Map<a, V>, hi: Map<a, V>, kb: String & Bool
) -> Map<a, V>:

def Map.put(a, V, m, key, x):

def Map.ins.splice.bit(
  a, -V: Kind(a), x: V, rest: Map<a, V>, pb: Nat, kb: String & Bool
) -> Map<a, V>:

def Map.ins.splice(
  a, -V: Kind(a), +p: Nat, key: String, x: V, rest: Map<a, V>
) -> Map<a, V>:

law Map.ins:
  for -a  : Quant
  for -V  : Kind(a)
  for m   : Map<a, V>
  for key : String
  for x   : V
  for +p  : Nat
  Map<a, V>

def Map.ins.deep(
  a, -V: Kind(a), x: V, lo: Map<a, V>, hi: Map<a, V>, pb: Nat, qb: Nat,
  kb: String & Bool
) -> Map<a, V>:

def Map.ins.if(
  a, -V: Kind(a), key: String, x: V, lo: Map<a, V>, hi: Map<a, V>, +p2: Nat,
  pb: Nat, t: Bool
) -> Map<a, V>:

def Map.ins(a, V, m, key, x, p):

def Map.lo(
  a, -V: Kind(a), -R: Type, p2: Nat, hi: Map<a, V>, r0: Map<a, V> & R
) -> Map<a, V> & R:

def Map.hi(
  a, -V: Kind(a), -R: Type, p2: Nat, lo: Map<a, V>, r0: Map<a, V> & R
) -> Map<a, V> & R:

law Map.seek:
  for -a  : Quant
  for -V  : Kind(a)
  for m   : Map<a, V>
  for key : String
  Map<a, V> & String & Maybe<&2, String>

def Map.seek.bit(
  a, -V: Kind(a), lo: Map<a, V>, hi: Map<a, V>, p2: Nat, kb: String & Bool
) -> Map<a, V> & String & Maybe<&2, String>:

def Map.seek(a, V, m, key):

def Map.set.fin.go(
  a, -V: Kind(a), m: Map<a, V>, key: String, x: V, r: (String & String) & Cmp
) -> Map<a, V>:

def Map.set.fin(
  a, -V: Kind(a), m: Map<a, V>, key: String, x: V, keyb: String, k: String
) -> Map<a, V>:

def Map.set.go(
  a, -V: Kind(a), x: V, r: Map<a, V> & String & Maybe<&2, String>
) -> Map<a, V>:

def Map.set(a, -V: Kind(a), m: Map<a, V>, key: String, x: V) -> Map<a, V>:

def Map.has.leaf(a, -V: Kind(a), v: V, r: (String & String) & Cmp) ->
  Map<a, V> & Bool:

law Map.has:
  for -a  : Quant
  for -V  : Kind(a)
  for m   : Map<a, V>
  for key : String
  Map<a, V> & Bool

def Map.has.bit(
  a, -V: Kind(a), lo: Map<a, V>, hi: Map<a, V>, p2: Nat, kb: String & Bool
) -> Map<a, V> & Bool:

def Map.has(a, V, m, key):

def Map.get.leaf(-V: Data, d: V, +v: V, r: (String & String) & Cmp) ->
  Map<&2, V> & V:

law Map.get:
  for -V  : Data
  for d   : V
  for m   : Map<&2, V>
  for key : String
  Map<&2, V> & V

def Map.get.bit(
  -V: Data, d: V, lo: Map<&2, V>, hi: Map<&2, V>, p2: Nat, kb: String & Bool
) -> Map<&2, V> & V:

def Map.get(V, d, m, key):

def Map.pop.lo(
  a, -V: Kind(a), pos: Nat, hi: Map<a, V>, r0: Map<a, V> & Maybe<a, V>
) -> Map<a, V> & Maybe<a, V>:

def Map.pop.hi(
  a, -V: Kind(a), pos: Nat, lo: Map<a, V>, r0: Map<a, V> & Maybe<a, V>
) -> Map<a, V> & Maybe<a, V>:

def Map.pop.leaf(a, -V: Kind(a), v: V, r: (String & String) & Cmp) ->
  Map<a, V> & Maybe<a, V>:

law Map.pop:
  for -a  : Quant
  for -V  : Kind(a)
  for m   : Map<a, V>
  for key : String
  Map<a, V> & Maybe<a, V>

def Map.pop.bit(
  a, -V: Kind(a), lo: Map<a, V>, hi: Map<a, V>, p2: Nat, kb: String & Bool
) -> Map<a, V> & Maybe<a, V>:

def Map.pop(a, V, m, key):

def Map.del.fin(a, -V: Kind(a), r: Map<a, V> & Maybe<a, V>) -> Map<a, V>:

def Map.del(a, -V: Kind(a), m: Map<a, V>, key: String) -> Map<a, V>:

def Map.to_list.go(
  a, -V: Kind(a), m: Map<a, V>, acc: List<a, Sigma<&2, a, String, _ => V>>
) -> List<a, Sigma<&2, a, String, _ => V>>:

def Map.to_list(a, -V: Kind(a), m: Map<a, V>) ->
  List<a, Sigma<&2, a, String, _ => V>>:

def Map.keys.go(a, -V: Kind(a), m: Map<a, V>, acc: List<&2, String>) ->
  List<&2, String>:

def Map.keys(a, -V: Kind(a), m: Map<a, V>) -> List<&2, String>:

def Map.from_list.go(
  a, -V: Kind(a), kvs: List<a, Sigma<&2, a, String, _ => V>>, m: Map<a, V>
) -> Map<a, V>:

def Map.from_list(a, -V: Kind(a), kvs: List<a, Sigma<&2, a, String, _ => V>>) ->
  Map<a, V>:

def Map.union(a, -V: Kind(a), m: Map<a, V>, n: Map<a, V>) -> Map<a, V>:

def Map.size(a, -V: Kind(a), m: Map<a, V>) -> Nat:

def Map.values.go(a, -V: Kind(a), m: Map<a, V>, acc: List<a, V>) -> List<a, V>:

def Map.values(a, -V: Kind(a), m: Map<a, V>) -> List<a, V>:

def Set() -> Data:

def Set.new() -> Set():

def Set.add(s: Set(), key: String) -> Set():

def Set.has(s: Set(), key: String) -> Set() & Bool:

def Set.del(s: Set(), key: String) -> Set():

def Set.size(s: Set()) -> Nat:

def Set.to_list(s: Set()) -> List<&2, String>:

def Set.from_list.go(keys: List<&2, String>, s: Set()) -> Set():

def Set.from_list(keys: List<&2, String>) -> Set():

```

### Array

```python
type Array<-T: Type> is Type:
  ALeaf{value: T}
  ANode{xs: Array<T>, ys: Array<T>}

def Array.size.node(-T: Type, ys: Array<T>, r: Array<T> & U32) ->
  Array<T> & U32:

def Array.size(-T: Type, a: Array<T>) -> Array<T> & U32:

def Array.swap.lo(-T: Type, ys: Array<T>, r: Array<T> & T) -> Array<T> & T:

def Array.swap.hi(-T: Type, xs: Array<T>, r: Array<T> & T) -> Array<T> & T:

law Array.swap.go:
  for -T: Type
  for  a: Array<T>
  for  n: U32
  for +i: U32
  for  v: T
  Array<T> & T

def Array.swap.if(
  -T: Type, xs: Array<T>, ys: Array<T>, +h: U32, i: U32, v: T, z: Bool
) -> Array<T> & T:

def Array.swap.go(T, a, n, i, v):

def Array.swap.at(-T: Type, i: U32, v: T, an: Array<T> & U32) -> Array<T> & T:

def Array.swap(-T: Type, a: Array<T>, +i: U32, v: T) -> Array<T> & T:

def Array.clone.node(
  -T: Data, cx: Array<T> & Array<T>, cy: Array<T> & Array<T>
) -> Array<T> & Array<T>:

def Array.clone(-T: Data, a: Array<T>) -> Array<T> & Array<T>:

def Array.new(-T: Data, +d: Nat, +v: T) -> Array<T>:

def Array.set.fin(-T: Type, r: Array<T> & T) -> Array<T>:

def Array.set(-T: Type, a: Array<T>, i: U32, v: T) -> Array<T>:

law Array.get.go:
  for -T: Data
  for  a: Array<T>
  for  n: U32
  for +i: U32
  Array<T> & T

def Array.get.if(
  -T: Data, xs: Array<T>, ys: Array<T>, +h: U32, i: U32, z: Bool
) -> Array<T> & T:

def Array.get.go(T, a, n, i):

def Array.get.at(-T: Data, i: U32, an: Array<T> & U32) -> Array<T> & T:

def Array.get(-T: Data, a: Array<T>, +i: U32) -> Array<T> & T:

def Array.to_list.go(~T: Type, a: Array<T>, acc: List<T>) -> List<T>:

def Array.to_list(~T: Type, a: Array<T>) -> List<T>:

def Array.map(~T: Type, ~U: Type, ~f: T -> U, a: Array<T>) -> Array<U>:

```

### IO / Chan / File / TCP / UDP / Socket / Listener (no random source, no argv, no stdin)

```python
law File:
  Type

law Socket:
  Type

law Listener:
  Type

law Chan:
  for -A: Type
  Data

type IO.OP<-R: Type> is Type:
  Emit{value: R}
  Halt{code: U32, message: String}

law IO:
  for -A: Type
  Type

def IO(A):

def IO.pure(-A: Type, x: A) -> IO(A):

def IO.bind(-A: Type, -B: Type, m: IO(A), f: A -> IO(B)) -> IO(B):

def IO.print(text: String) -> IO(Unit):

def IO.write(text: String) -> IO(Unit):

def IO.print_err(text: String) -> IO(Unit):

def IO.get_env(name: String) -> IO(Result<&1, &1, U32 & String, String>):

def IO.die(-A: Type, code: U32, msg: String) -> IO(A):

def IO.pass(-A: Type, r: Result<&1, &1, U32 & String, A>) -> IO(A):

def IO.try(-A: Type, act: IO(Result<&1, &1, U32 & String, A>)) -> IO(A):

def IO.spawn(-A: Type, act: IO(A)) -> IO(Unit):

def IO.sleep(ms: U32) -> IO(Unit):

def IO.now() -> IO(Nat):

def Chan.new(-A: Type, room: U32) -> IO(Chan(A)):

def Chan.send(-A: Type, chan: Chan(A), value: A) -> IO(Bool):

def Chan.recv(-A: Type, chan: Chan(A)) -> IO(Maybe<&1, A>):

def Chan.close(-A: Type, chan: Chan(A)) -> IO(Unit):

def IO.fork.go(-A: Type, act: IO(A), chan: Chan(A)) -> IO(Chan(A)):

def IO.fork(-A: Type, act: IO(A)) -> IO(Chan(A)):

def IO.join.go(-A: Type, chan: Chan(A), got: Maybe<&1, A>) -> IO(A):

def IO.join(-A: Type, +chan: Chan(A)) -> IO(A):

def File.open(path: String, mode: String) ->
  IO(Result<&1, &1, U32 & String, File>):

def File.read(file: File, max: U32) ->
  IO(File & Result<&1, &1, U32 & String, String>):

def File.read_bytes(file: File, max: U32) ->
  IO(File & Result<&1, &1, U32 & String, List<&2, U32>>):

def File.write(file: File, data: String) ->
  IO(File & Result<&1, &1, U32 & String, Unit>):

def File.close(file: File) -> IO(Unit):

def TCP.listen(port: U32) -> IO(Result<&1, &1, U32 & String, Listener>):

def TCP.accept(listener: Listener) ->
  IO(Listener & Result<&1, &1, U32 & String, Socket>):

def TCP.connect(host: String, port: U32) ->
  IO(Result<&1, &1, U32 & String, Socket>):

def TCP.send(sock: Socket, data: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):

def TCP.recv(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, String>):

def UDP.bind(port: U32) -> IO(Result<&1, &1, U32 & String, Socket>):

def UDP.send_to(sock: Socket, host: String, port: U32, data: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):

def UDP.recv_from(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, String & U32 & String>):

def UDP.poll(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, Maybe<&1, String & U32 & String>>):

def Socket.close(socket: Socket) -> IO(Unit):

def Listener.close(listener: Listener) -> IO(Unit):

```

### Window / Audio / App / Image / Event

```python
type Image is Data:
  Pix{color: U32}
  Qua{tl: Image, tr: Image, bl: Image, br: Image}

type Event is Data:
  Key{code: U32, down: Bool}
  Mouse{x: U32, y: U32, button: U32, down: Bool}
  Move{x: U32, y: U32}
  Close{}

law Window:
  Type

law Audio:
  Type

type App<-S: Type> is Type:
  App{view: S -> Pair(S, Image), tick: List<Event> -> S -> IO(Maybe<S>)}

def Window.open(title: String, width: U32, height: U32) ->
  IO(Result<&1, &1, U32 & String, Window>):

def Window.frame(window: Window, image: Image) ->
  IO(Window & Image & List<Event>):

def Window.set_title(window: Window, title: String) -> IO(Window):

def Window.close(window: Window) -> IO(Unit):

def Audio.open(rate: U32) -> IO(Result<&1, &1, U32 & String, Audio>):

def Audio.write(audio: Audio, samples: List<&2, F32>) -> IO(Audio & U32):

def Audio.close(audio: Audio) -> IO(Unit):

def Image.sink(img: Image) -> Unit:

def Image.drop.join(a: Unit, b: Unit, c: Unit, d: Unit) -> Unit:

def Image.free(+k: Nat, img: Image) -> Unit:

def Image.drop(img: Image) -> Unit:

def App.next(
  -S: Type, window: Window, rest: Window -> S -> IO(Unit), next: Maybe<S>
) -> IO(Unit):

def App.turn(
  -S: Type, shown: Window & Image & List<Event>,
  tick: List<Event> -> S -> IO(Maybe<S>), state: S,
  rest: Window -> S -> IO(Unit)
) -> IO(Unit):

def App.draw(
  -S: Type, window: Window, drawn: S & Image,
  tick: List<Event> -> S -> IO(Maybe<S>), rest: Window -> S -> IO(Unit)
) -> IO(Unit):

def App.step(
  -S: Type, app: App<S>, window: Window, state: S,
  rest: Window -> S -> IO(Unit)
) -> IO(Unit):

def App.loop(~S: Type, ~app: App<S>, fuel: Nat, window: Window, state: S) ->
  IO(Unit):

def App.run(
  ~S: Type, ~app: App<S>, title: String, width: U32, height: U32, state: S
) -> IO(Unit):

def App.more(-S: Type, rest: S -> IO(Maybe<S>), next: Maybe<S>) ->
  IO(Maybe<S>):

def App.fold(
  -S: Type, app: App<S>, events: List<Event>, state: S,
  rest: S -> IO(Maybe<S>)
) -> IO(Maybe<S>):

def App.play(~S: Type, ~app: App<S>, frames: List<List<Event>>, state: S) ->
  IO(Maybe<S>):

```

Not in Base: any random source (seed a xorshift from `IO.now()`), argv, stdin, `F32.cmp`, `F32` literals with a sign, U64/F64, complex numbers, `List.sum`, `List.zip_with`, `Array.fold`, `Array.zip`, an `Array<F32>` index sugar (`a[i]` assumes `Array<U32>`; use `Array.get`/`Array.set`/`Array.swap`).

## Idioms (verbatim excerpts)

### Dependent type family (GUIDE.md)

```
Since types are terms, a def may return a `Type`, like `def IsEven(n: Nat) ->
Type:`, which is all dependent types are.
```

Base does it with a law plus a def (`base.bend` 44-52, 133-138):

```python
law Word:
  for n: Nat
  Data

def Word(n):
  match n:
    case 0n:
      Word.Nil
    case 1n+p:
      Word.Con<p>
```

`tests/reg/brw_audit3_dependent_array.bend` matches on the index and then on the value whose type was refined:

```python
def audit_shape(tag: Bool) -> Type:
  match tag:
    case False{}:
      String
    case True{}:
      Array<U32>

def audit_read(tag: Bool, value: audit_shape(tag)) -> U32:
  match tag:
    case False{}:
      match value:
        case SNil{}:
          0
```

### Match on several scrutinees, constructor and cons patterns (base.bend List.zip; bench tree-matmul)

```python
  match xs ys:
    case Nil{} _:
      Nil{}
    case h <> t Nil{}:
      Nil{}
    case x <> xt y <> yt:
      (x, y) <> List.zip(a, A, b, B, xt, yt)
```

```python
    case Lf{x} Qd{b0, b1, b2, b3}:
      Lf{0}
    case Qd{a0, a1, a2, a3} Qd{b0, b1, b2, b3}:
      p0 q0 p1 q1 p2 q2 p3 q3 = mul(a0, b0) mul(a1, b2) mul(a0, b1) mul(a1, b3) mul(a2, b0) mul(a3, b2) mul(a2, b1) mul(a3, b3)
      add4(p0, q0, p1, q1, p2, q2, p3, q3)
```

Nat patterns: `case 0n:`, `case 1n+p:`, `case 1n++p:` (the `++` makes `p` reusable; used in `demos/pure_par_sum/main.bend` where `p` feeds both forks), `case 21n+p:` (merkle rk), `case 2n+a 0n:` (proof_numerics). Matching a `+` value hands out `+` fields; on a plain one write `+r` in the pattern (`case ALeaf{+x}:`).

### Match restrictions (GUIDE.md, and checker messages seen here)

```
A `match` inspects a parameter or a variable bound by a pattern, never a
computed value: `match sum(xs, 0):` is rejected. Scrutinees follow binder order,
and a `let` may not precede a `match` on a parameter. To match on a computed
value, pass it to a helper that matches on its parameter.
```

A destructuring let IS a match. Verified error texts:

```
- message  : a parameter or field scrutinee (a match cannot scrutinize a local binder: give it its own def)
- message  : a parameter or field scrutinee (a match cannot scrutinize a computed value: give it its own def)
```

So `(p0, q0) = a` after `a b = f() g()` and `(a, b) = dup(...)` are both rejected. Base's idiom is a join def that takes the pair as a parameter (`base.bend` 2134-2140):

```python
def Array.swap.lo(-T: Type, ys: Array<T>, r: Array<T> & T) -> Array<T> & T:
  (nxs, old) = r
  (ANode{nxs, ys}, old)
```

### Parallel let (GUIDE.md; base.bend Array.map; bench tree-matmul)

```python
      a b = pow2(p) pow2(p) # parallel call
```

```python
    case ANode{xs, ys}:
      l r = Array.map(~T, ~U, ~f, xs) Array.map(~T, ~U, ~f, ys)
      ANode{l, r}
```

```python
  +a +b = gen(d, U32.inc(s)) gen(d, U32.add(s, 2))
```

It binds names only. Verified error for a pattern on the left:

```
- message  : a name (a parallel let binds names; destructure in its body)
```

### Reusable lets and erased binders

```python
      +h = U32.shr(n)                       # base.bend Array.swap.go
      +x = {l : C}                          # smoke plus2.bend: a leaf of Q(n) needs the annotation
```

Verified: `+x = l` with `l : Q(n)` refined to `Q(0n)` fails with `expected : Data / observed : Type` (the kind comes from the declared family `Q : Nat -> Type`, not from the normalized `C`); `+x = {l : C}` checks. A live use of an erased binder fails: `expected : -n / observed : n (consumed more than once)`.

### Modules (GUIDE.md; verified in smoke/laws.bend)

```python
import ./math.bend as M  # M.x now names every def of math.bend
```

`import ./q.bend as S` then `for q: S.Q(n)` in a law, `S.apply(...)`, `S.C.norm2(...)`, `S.Skip{} <> skips(p)` all check. Error messages print the module by file stem (`q.apply`, `q.Gate{...}`) and shadowed binders as `p^0`.

### The `#|` test convention (tests/run/float_printing.bend, tests/run/array_bounds_000.bend)

```python
def main():
  IO.print(main.out())

#|2 100.25 0.33333334 0.0009765625 123456
```

```
#|Error:
#|- expected : 'def', 'type' or 'law'
#|- observed : ':'
#|Location:
#|10 | def main():
#|11>|   m : [:U32] = ![0:10, 1:20, 3:7, _:0; 4]
#|12 |   m[0]
#|exit 1
```

Each `#|` line is one expected stdout/stderr line; `#|exit N` pins the exit code. Tests declare `law main: IO(Unit)` then `def main():`.

### Law and proof (GUIDE.md; demos/pure_par_sum)

```python
law add_zero:
  for x: Nat
  {Nat.add(x, 0n) == x : Nat}

def add_zero(x):
  match x:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}
```

`%e : P` with `e : {a == b : T}`: `P` is the current goal with `_` marking `b`; the goal becomes `P` with `a` there. Verified in smoke/laws.bend: the motive marks the right-hand side, e.g. with IH `skip_id(p, l) : {apply(..l) == l}` and goal `{(apply(..l), apply(..r)) == (l, r)}` the rewrite is `%skip_id(p, l) : {(apply(..l), apply(..r)) == (_, r) : Q(1n+p)}`. A destructuring let `(l, r) = q` on a `for q: Q(n)` parameter refines the goal to `(l, r)`.

LAWS/PROOF layout (`demos/pure_par_sum/LAWS.bend`, `PROOF.bend`):

```python
import ./main.bend as Par
law tree_is_seq:
  for +d: Nat
  for +i: Nat
  {Par.sum(d, i) == Par.seq(Par.pow2(d), i) : Nat}
```

```python
import ./LAWS.bend as Laws
def Laws.tree_is_seq(d, i):
  match d:
    case 0n:
      {==}
    case 1n++p:
      %seq_add(Par.pow2(p), Par.pow2(p), i) : {Nat.add(Par.sum(p, i), Par.sum(p, Nat.add(Par.pow2(p), i))) == _ : Nat}
```

### How the benches parallelize (bench/runtime)

- `pure_par_sum`, `merkle`, `nbody`, `tree-matmul`: recursion on a `Nat` depth, one parallel let per level, forking all the way to the leaf. No depth cutoff anywhere; nbody's leaf is a sequential loop over 8 systems (`chunk(8n, ...)`), tree-matmul forks 8-way per node.
- `!` is placed once, on the top-level call in `main`: `sum!(16n, 0n)`, `build!(22n, 0)`, `batch!(blog(), ...)`, `run!(sy(), st())`.
- nbody gets `F32.sqrt` directly (`F32.div(U32.to_f32(1), F32.sqrt(da))`), spells constants as `fl(n, d) = F32.div(U32.to_f32(n), U32.to_f32(d))`, and keeps 21 `+F32` registers as parameters of a `Nat`-fueled tail-recursive loop.
- PRNG in nbody: `def prng(+x: U32) -> U32: +b = U32.xor(x, U32.shln(x, 13n)); +d = U32.xor(b, U32.shrn(b, 17n)); U32.xor(d, U32.shln(d, 5n))` (xorshift32).

### What proof_numerics proves

Only `Nat` algebra over the demo's own `add`, `mul`, `divmod`: `add_comm`, `add_assoc`, `mul_comm`, `mul_dist`, and `divmod_ok` (with `exs q`, `exs r` witnesses and a `Bool`-indexed type `BD` to refute `True{} == False{}`). Nothing about `F32` or `U32`; Base ships `U32.add_comm` and `Word.add_comm` as its only arithmetic laws.
