import Base
import ./q.bend as S

def skips(n: Nat) -> List<&2, S.Role>:
  match n:
    case 0n:
      Nil{}
    case 1n++p:
      S.Skip{} <> skips(p)

# LAW 1: an empty role list changes nothing (trivial: apply returns q at once)
law nil_id:
  for n: Nat
  for q: S.Q(n)
  {S.apply(n, Nil{}, S.H(), q) == q : S.Q(n)}

def nil_id(n, q):
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

# LAW 2: a gate that targets no qubit (all Skip) changes nothing; by
# induction on n, destructuring q in the step case
law skip_id:
  for n: Nat
  for q: S.Q(n)
  {S.apply(n, skips(n), S.H(), q) == q : S.Q(n)}

def skip_id(n, q):
  match n:
    case 0n:
      {==}
    case 1n++p:
      (l, r) = q
      %skip_id(p, l) : {(S.apply(p, skips(p), S.H(), l), S.apply(p, skips(p), S.H(), r)) == (_, r) : S.Q(1n+p)}
      %skip_id(p, r) : {(S.apply(p, skips(p), S.H(), l), S.apply(p, skips(p), S.H(), r)) == (S.apply(p, skips(p), S.H(), l), _) : S.Q(1n+p)}
      {==}
