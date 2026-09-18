# Proofs of the exact amplitude laws. Each gate is a permutation, a negation
# or a rotation of the four integers, so once an amplitude and its integers
# are taken apart, eight rotations or two negations compute back to it.
import Base
import ./exact.bend as A
import ./LAWS_exact.bend as Laws

# two negations of every integer return the amplitude
def neg_neg(x: A.C) -> {A.C.neg(A.C.neg(x)) == x : A.C}:
  match x:
    case A.C{a, b, c, d, k}:
      match a b c d:
        case A.Int{p1, n1} A.Int{p2, n2} A.Int{p3, n3} A.Int{p4, n4}:
          {==}

# eight rotations by w return the amplitude
def rot8_id(x: A.C) -> {A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(x)))))))) == x : A.C}:
  match x:
    case A.C{a, b, c, d, k}:
      match a b c d:
        case A.Int{p1, n1} A.Int{p2, n2} A.Int{p3, n3} A.Int{p4, n4}:
          {==}

def Laws.x_x(x, y):
  {==}

def Laws.y_y(x, y):
  %rot8_id(x) : {(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(x)))))))), A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (_, y) : A.C & A.C}
  %rot8_id(y) : {(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(x)))))))), A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(x)))))))), _) : A.C & A.C}
  {==}

def Laws.z_z(x, y):
  %neg_neg(y) : {(x, A.C.neg(A.C.neg(y))) == (x, _) : A.C & A.C}
  {==}

# S then Sdg is w^2 then w^6, and so on: eight rotations in all
def Laws.s_sdg(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

def Laws.sdg_s(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

def Laws.t_tdg(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

def Laws.tdg_t(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

def Laws.s4(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

def Laws.t8(x, y):
  %rot8_id(y) : {(x, A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(A.C.rot(y))))))))) == (x, _) : A.C & A.C}
  {==}

#|All terms check.
