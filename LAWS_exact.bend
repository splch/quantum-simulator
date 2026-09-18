# Laws about the exact amplitudes of exact.bend: gate identities that hold
# structurally on the pair of amplitudes a gate acts on. They are unprovable
# with F32 amplitudes, where every primitive is opaque. PROOF_exact.bend
# proves them; test.sh generates the exact build first.
import Base
import ./exact.bend as A

# g on the amplitude pair
def apply2(g: A.Gate, xy: A.C & A.C) -> A.C & A.C:
  (x, y) = xy
  A.Gate.apply(g, x, y)

# g applied k times
def pow(k: Nat, +g: A.Gate, xy: A.C & A.C) -> A.C & A.C:
  match k:
    case 0n:
      xy
    case 1n+j:
      pow(j, g, apply2(g, xy))

# LAW: X, Y and Z are their own inverses
law x_x:
  for x: A.C
  for y: A.C
  {apply2(A.X(), apply2(A.X(), (x, y))) == (x, y) : A.C & A.C}

law y_y:
  for x: A.C
  for y: A.C
  {apply2(A.Y(), apply2(A.Y(), (x, y))) == (x, y) : A.C & A.C}

law z_z:
  for x: A.C
  for y: A.C
  {apply2(A.Z(), apply2(A.Z(), (x, y))) == (x, y) : A.C & A.C}

# LAW: S and Sdg, T and Tdg undo each other in either order
law s_sdg:
  for x: A.C
  for y: A.C
  {apply2(A.Sdg(), apply2(A.S(), (x, y))) == (x, y) : A.C & A.C}

law sdg_s:
  for x: A.C
  for y: A.C
  {apply2(A.S(), apply2(A.Sdg(), (x, y))) == (x, y) : A.C & A.C}

law t_tdg:
  for x: A.C
  for y: A.C
  {apply2(A.Tdg(), apply2(A.T(), (x, y))) == (x, y) : A.C & A.C}

law tdg_t:
  for x: A.C
  for y: A.C
  {apply2(A.T(), apply2(A.Tdg(), (x, y))) == (x, y) : A.C & A.C}

# LAW: S^4 = I and T^8 = I
law s4:
  for x: A.C
  for y: A.C
  {pow(4n, A.S(), (x, y)) == (x, y) : A.C & A.C}

law t8:
  for x: A.C
  for y: A.C
  {pow(8n, A.T(), (x, y)) == (x, y) : A.C & A.C}
