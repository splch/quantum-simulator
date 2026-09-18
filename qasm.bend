import Base
import ./amp.bend as A
import ./sim.bend as S
import ./circuits.bend as G
import ./rotations.bend as R

# An OpenQASM 2 subset reader.
#   QASM=path SHOTS=n bend qasm.bend
# reads the file, builds the circuit, and prints the qubit and op counts,
# the amplitudes (rounded, for up to five qubits) and a histogram of SHOTS
# shots (default 1024). Supported: one qreg; the qelib1 gates id h x y z s
# sdg t tdg rx ry rz p u1 u2 u3 cx cy cz swap ccx cp cu1 crz; angles as
# expressions over numbers, pi, + - * / and parentheses; a gate on a bare
# register applies to every qubit; OPENQASM, include, creg and barrier are
# accepted and ignored; measure is ignored and the final state is sampled
# instead; anything else is reported and skipped. Strings are lists here,
# so this is for small files.

# Tokens
# ------

type Tok is Data:
  Name{s: String}
  Num{s: String}
  LPar{}
  RPar{}
  LBr{}
  RBr{}
  Comma{}
  Semi{}
  Plus{}
  Minus{}
  Star{}
  Slash{}
  Gt{}
  Other{c: Char}

# the class of a character, computed once so that the lexer can match on it
type Cls is Data:
  Alpha{}
  Digit{}
  Space{}
  Quote{}
  Punct{}

def cls(+c: Char) -> Cls:
  Bool.pick(Cls, Char.is_alpha(c) || Char.is_eq(c, '_'), Alpha{}, Bool.pick(Cls, Char.is_digit(c) || Char.is_eq(c, '.'), Digit{}, Bool.pick(Cls, Char.is_space(c), Space{}, Bool.pick(Cls, Char.is_eq(c, '"'), Quote{}, Punct{}))))

def sym(+c: Char) -> Tok:
  Bool.pick(Tok, Char.is_eq(c, ';'), Semi{}, Bool.pick(Tok, Char.is_eq(c, ','), Comma{}, Bool.pick(Tok, Char.is_eq(c, '('), LPar{}, Bool.pick(Tok, Char.is_eq(c, ')'), RPar{}, Bool.pick(Tok, Char.is_eq(c, '['), LBr{}, Bool.pick(Tok, Char.is_eq(c, ']'), RBr{}, Bool.pick(Tok, Char.is_eq(c, '+'), Plus{}, Bool.pick(Tok, Char.is_eq(c, '-'), Minus{}, Bool.pick(Tok, Char.is_eq(c, '*'), Star{}, Bool.pick(Tok, Char.is_eq(c, '>'), Gt{}, Other{c}))))))))))

# the lexer's state: what it is inside, the characters of the current word
# or number (reversed), the tokens so far (reversed)
type Mode is Data:
  Free{}
  InWord{}
  InNum{}
  Comment{}
  Str{}
  Slash1{}

type Lx is Data:
  Lx{mode: Mode, buf: List<&2, Char>, acc: List<&2, Tok>}

# the token collected so far, pushed onto the tokens
def flush(mode: Mode, buf: List<&2, Char>, acc: List<&2, Tok>) -> List<&2, Tok>:
  match mode:
    case InWord{}:
      Name{String.from_list(List.reverse(&2, Char, buf))} <> acc
    case InNum{}:
      Num{String.from_list(List.reverse(&2, Char, buf))} <> acc
    case Slash1{}:
      Slash{} <> acc
    case _:
      acc

# a character met between tokens
def free.punct(slash: Bool, c: Char, acc: List<&2, Tok>) -> Lx:
  match slash:
    case True{}:
      Lx{Slash1{}, Nil{}, acc}
    case False{}:
      Lx{Free{}, Nil{}, sym(c) <> acc}

def free(k: Cls, +c: Char, acc: List<&2, Tok>) -> Lx:
  match k:
    case Alpha{}:
      Lx{InWord{}, [c], acc}
    case Digit{}:
      Lx{InNum{}, [c], acc}
    case Space{}:
      Lx{Free{}, Nil{}, acc}
    case Quote{}:
      Lx{Str{}, Nil{}, acc}
    case Punct{}:
      free.punct(Char.is_eq(c, '/'), c, acc)

def step.comment(nl: Bool, acc: List<&2, Tok>) -> Lx:
  match nl:
    case True{}:
      Lx{Free{}, Nil{}, acc}
    case False{}:
      Lx{Comment{}, Nil{}, acc}

# after one slash: a second one opens a comment, anything else was a division
def step.slash(again: Bool, k: Cls, c: Char, acc: List<&2, Tok>) -> Lx:
  match again:
    case True{}:
      Lx{Comment{}, Nil{}, acc}
    case False{}:
      free(k, c, Slash{} <> acc)

# one character in the current mode
def step.at(mode: Mode, +k: Cls, +c: Char, buf: List<&2, Char>, acc: List<&2, Tok>) -> Lx:
  match mode k:
    case Free{} _:
      free(k, c, acc)
    case InWord{} Alpha{}:
      Lx{InWord{}, c <> buf, acc}
    case InWord{} Digit{}:
      Lx{InWord{}, c <> buf, acc}
    case InWord{} _:
      free(k, c, flush(InWord{}, buf, acc))
    case InNum{} Digit{}:
      Lx{InNum{}, c <> buf, acc}
    case InNum{} _:
      free(k, c, flush(InNum{}, buf, acc))
    case Comment{} _:
      step.comment(Char.is_eq(c, '\n'), acc)
    case Str{} Quote{}:
      Lx{Free{}, Nil{}, acc}
    case Str{} _:
      Lx{Str{}, Nil{}, acc}
    case Slash1{} _:
      step.slash(Char.is_eq(c, '/'), k, c, acc)

def step(k: Cls, c: Char, st: Lx) -> Lx:
  match st:
    case Lx{mode, buf, acc}:
      step.at(mode, k, c, buf, acc)

def lex.fin(st: Lx) -> List<&2, Tok>:
  match st:
    case Lx{mode, buf, acc}:
      List.reverse(&2, Tok, flush(mode, buf, acc))

def lex(+cs: List<&2, Char>, st: Lx) -> List<&2, Tok>:
  match cs:
    case Nil{}:
      lex.fin(st)
    case c <> rest:
      lex(rest, step(cls(c), c, st))

def tokens(text: String) -> List<&2, Tok>:
  lex(String.to_list(text), Lx{Free{}, Nil{}, Nil{}})

# a finished token group (reversed) onto a list of groups, if not empty
def close(+cur: List<&2, Tok>, acc: List<&2, List<&2, Tok>>) -> List<&2, List<&2, Tok>>:
  match cur:
    case Nil{}:
      acc
    case _:
      List.reverse(&2, Tok, cur) <> acc

# the statements: the tokens split at semicolons
def stmts(ts: List<&2, Tok>, cur: List<&2, Tok>, acc: List<&2, List<&2, Tok>>) -> List<&2, List<&2, Tok>>:
  match ts:
    case Nil{}:
      List.reverse(&2, List<&2, Tok>, close(cur, acc))
    case Semi{} <> rest:
      stmts(rest, Nil{}, close(cur, acc))
    case t <> rest:
      stmts(rest, t <> cur, acc)

# Angles
# ------
# expressions over numbers, pi, + - * /, parentheses and a unary minus, by
# the shunting-yard method over a value stack and an operator stack; a
# malformed expression yields 0

type Ev is Data:
  Ev{vals: List<&2, F32>, ops: List<&2, Tok>, unary: Bool}

# a op b for a binary operator; the stack holds b above a
def binop(op: Tok, vals: List<&2, F32>) -> List<&2, F32>:
  match op vals:
    case Plus{} b <> a <> rest:
      F32.add(a, b) <> rest
    case Minus{} b <> a <> rest:
      F32.sub(a, b) <> rest
    case Star{} b <> a <> rest:
      F32.mul(a, b) <> rest
    case Slash{} b <> a <> rest:
      F32.div(a, b) <> rest
    case _ _:
      [0.0]

# pop and apply the operators that bind at least as tightly as the incoming
# token (Semi marks the end of the expression); a left parenthesis stops the
# popping, and a right parenthesis removes it
def pops(ops: List<&2, Tok>, vals: List<&2, F32>, +inc: Tok) -> Ev:
  match ops inc:
    case Nil{} _:
      Ev{vals, Nil{}, False{}}
    case LPar{} <> rest RPar{}:
      Ev{vals, rest, False{}}
    case LPar{} <> rest _:
      Ev{vals, LPar{} <> rest, False{}}
    case Plus{} <> rest Star{}:
      Ev{vals, Plus{} <> rest, False{}}
    case Plus{} <> rest Slash{}:
      Ev{vals, Plus{} <> rest, False{}}
    case Minus{} <> rest Star{}:
      Ev{vals, Minus{} <> rest, False{}}
    case Minus{} <> rest Slash{}:
      Ev{vals, Minus{} <> rest, False{}}
    case op <> rest _:
      pops(rest, binop(op, vals), inc)

def push(op: Tok, st: Ev) -> Ev:
  match st:
    case Ev{vals, ops, u}:
      Ev{vals, op <> ops, True{}}

# one token of an expression
def evstep(t: Tok, st: Ev) -> Ev:
  match t st:
    case Num{s} Ev{vals, ops, u}:
      Ev{Maybe.default(&2, F32, F32.read(s), 0.0) <> vals, ops, False{}}
    case Name{s} Ev{vals, ops, u}:
      Ev{Bool.pick(F32, String.eq(s, "pi"), F32.pi(), 0.0) <> vals, ops, False{}}
    case LPar{} Ev{vals, ops, u}:
      Ev{vals, LPar{} <> ops, True{}}
    case RPar{} Ev{vals, ops, u}:
      pops(ops, vals, RPar{})
    case Minus{} Ev{vals, ops, True{}}:
      push(Minus{}, pops(ops, 0.0 <> vals, Minus{}))
    case Minus{} Ev{vals, ops, False{}}:
      push(Minus{}, pops(ops, vals, Minus{}))
    case Plus{} Ev{vals, ops, u}:
      push(Plus{}, pops(ops, vals, Plus{}))
    case Star{} Ev{vals, ops, u}:
      push(Star{}, pops(ops, vals, Star{}))
    case Slash{} Ev{vals, ops, u}:
      push(Slash{}, pops(ops, vals, Slash{}))
    case _ Ev{vals, ops, u}:
      Ev{vals, ops, u}

def eval.top(st: Ev) -> F32:
  match st:
    case Ev{vals, ops, u}:
      match vals:
        case Nil{}:
          0.0
        case v <> rest:
          v

def eval.fin(st: Ev) -> F32:
  match st:
    case Ev{vals, ops, u}:
      eval.top(pops(ops, vals, Semi{}))

def eval.go(ts: List<&2, Tok>, st: Ev) -> F32:
  match ts:
    case Nil{}:
      eval.fin(st)
    case t <> rest:
      eval.go(rest, evstep(t, st))

def eval(ts: List<&2, Tok>) -> F32:
  eval.go(ts, Ev{Nil{}, Nil{}, True{}})

def evals(lists: List<&2, List<&2, Tok>>) -> List<&2, F32>:
  match lists:
    case Nil{}:
      Nil{}
    case l <> rest:
      eval(l) <> evals(rest)

# Statements
# ----------

# the argument expressions between the parentheses after a gate name, split
# at top-level commas, beside the tokens after the closing parenthesis
def args(ts: List<&2, Tok>, depth: Nat, cur: List<&2, Tok>, acc: List<&2, List<&2, Tok>>) -> List<&2, List<&2, Tok>> & List<&2, Tok>:
  match ts depth:
    case Nil{} _:
      (List.reverse(&2, List<&2, Tok>, close(cur, acc)), Nil{})
    case RPar{} <> rest 0n:
      (List.reverse(&2, List<&2, Tok>, close(cur, acc)), rest)
    case RPar{} <> rest 1n+d:
      args(rest, d, RPar{} <> cur, acc)
    case LPar{} <> rest d:
      args(rest, 1n+d, LPar{} <> cur, acc)
    case Comma{} <> rest 0n:
      args(rest, 0n, Nil{}, close(cur, acc))
    case t <> rest d:
      args(rest, d, t <> cur, acc)

# the qubit arguments q[i], in order; all when a bare register was named
type Qs is Data:
  Qs{qs: List<&2, Nat>, all: Bool}

def qubits(ts: List<&2, Tok>, acc: List<&2, Nat>, all: Bool) -> Qs:
  match ts:
    case Nil{}:
      Qs{List.reverse(&2, Nat, acc), all}
    case Name{r} <> LBr{} <> Num{i} <> RBr{} <> rest:
      qubits(rest, Maybe.default(&2, Nat, Nat.read(i), 0n) <> acc, all)
    case Name{r} <> rest:
      qubits(rest, acc, True{})
    case Gt{} <> rest:
      Qs{List.reverse(&2, Nat, acc), all}
    case t <> rest:
      qubits(rest, acc, all)

# the gate names, and the statements that are not gates
type Gn is Data:
  Nid{}
  Nh{}
  Nx{}
  Ny{}
  Nz{}
  Ns{}
  Nsdg{}
  Nt{}
  Ntdg{}
  Nrx{}
  Nry{}
  Nrz{}
  Np{}
  Nu2{}
  Nu3{}
  Ncx{}
  Ncy{}
  Ncz{}
  Nswap{}
  Nccx{}
  Ncp{}
  Ncrz{}
  Nqreg{}
  Nmeasure{}
  Nskip{}
  Nunknown{}

def gname(+s: String) -> Gn:
  Bool.pick(Gn, String.eq(s, "h"), Nh{}, Bool.pick(Gn, String.eq(s, "x"), Nx{}, Bool.pick(Gn, String.eq(s, "y"), Ny{}, Bool.pick(Gn, String.eq(s, "z"), Nz{}, Bool.pick(Gn, String.eq(s, "s"), Ns{}, Bool.pick(Gn, String.eq(s, "sdg"), Nsdg{}, Bool.pick(Gn, String.eq(s, "t"), Nt{}, Bool.pick(Gn, String.eq(s, "tdg"), Ntdg{}, Bool.pick(Gn, String.eq(s, "rx"), Nrx{}, Bool.pick(Gn, String.eq(s, "ry"), Nry{}, Bool.pick(Gn, String.eq(s, "rz"), Nrz{}, Bool.pick(Gn, String.eq(s, "p") || String.eq(s, "u1"), Np{}, Bool.pick(Gn, String.eq(s, "u2"), Nu2{}, Bool.pick(Gn, String.eq(s, "u3") || String.eq(s, "u"), Nu3{}, Bool.pick(Gn, String.eq(s, "cx") || String.eq(s, "CX"), Ncx{}, Bool.pick(Gn, String.eq(s, "cy"), Ncy{}, Bool.pick(Gn, String.eq(s, "cz"), Ncz{}, Bool.pick(Gn, String.eq(s, "swap"), Nswap{}, Bool.pick(Gn, String.eq(s, "ccx"), Nccx{}, Bool.pick(Gn, String.eq(s, "cp") || String.eq(s, "cu1"), Ncp{}, Bool.pick(Gn, String.eq(s, "crz"), Ncrz{}, Bool.pick(Gn, String.eq(s, "id"), Nid{}, Bool.pick(Gn, String.eq(s, "qreg"), Nqreg{}, Bool.pick(Gn, String.eq(s, "measure"), Nmeasure{}, Bool.pick(Gn, String.eq(s, "OPENQASM") || String.eq(s, "include") || String.eq(s, "creg") || String.eq(s, "barrier"), Nskip{}, Nunknown{})))))))))))))))))))))))))

# the i-th angle, 0 when missing
def angle(angs: List<&2, F32>, i: Nat) -> F32:
  Maybe.default(&2, F32, List.get(&2, F32, angs, i), 0.0)

# the ops of one gate on its qubits; a wrong number of qubits gives none
def ops(g: Gn, +angs: List<&2, F32>, qs: List<&2, Nat>) -> List<&2, S.Op>:
  match g qs:
    case Nid{} _:
      Nil{}
    case Nh{} q <> _:
      [G.h(q)]
    case Nx{} q <> _:
      [G.x(q)]
    case Ny{} q <> _:
      [G.y(q)]
    case Nz{} q <> _:
      [G.z(q)]
    case Ns{} q <> _:
      [G.s(q)]
    case Nsdg{} q <> _:
      [G.sdg(q)]
    case Nt{} q <> _:
      [G.t(q)]
    case Ntdg{} q <> _:
      [G.tdg(q)]
    case Nrx{} q <> _:
      [R.rx(angle(angs, 0n), q)]
    case Nry{} q <> _:
      [R.ry(angle(angs, 0n), q)]
    case Nrz{} q <> _:
      [R.rz(angle(angs, 0n), q)]
    case Np{} q <> _:
      [R.p(angle(angs, 0n), q)]
    case Nu2{} q <> _:
      [R.u2(angle(angs, 0n), angle(angs, 1n), q)]
    case Nu3{} q <> _:
      [R.u3(angle(angs, 0n), angle(angs, 1n), angle(angs, 2n), q)]
    case Ncx{} c <> q <> _:
      [G.cx(c, q)]
    case Ncy{} c <> q <> _:
      [G.ctrl([c], q, A.Y())]
    case Ncz{} c <> q <> _:
      [G.cz(c, q)]
    case Nswap{} a <> b <> _:
      G.swap(a, b)
    case Nccx{} a <> b <> q <> _:
      [G.ccx(a, b, q)]
    case Ncp{} c <> q <> _:
      [R.cp(angle(angs, 0n), c, q)]
    case Ncrz{} c <> q <> _:
      [G.ctrl([c], q, A.RZ(angle(angs, 0n)))]
    case _ _:
      Nil{}

# a one-qubit gate on every qubit of the register
def bcast(+g: Gn, +angs: List<&2, F32>, qs: List<&2, Nat>) -> List<&2, S.Op>:
  match qs:
    case Nil{}:
      Nil{}
    case q <> rest:
      List.append(&2, S.Op, ops(g, angs, [q]), bcast(g, angs, rest))

# the program: the qubit count, the ops in order, the notes (reversed), and
# whether a measure was seen
type Prog is Data:
  Prog{n: Nat, ops: List<&2, S.Op>, notes: List<&2, String>, measured: Bool}

def stmt.qs(+g: Gn, +angs: List<&2, F32>, +n: Nat, o: List<&2, S.Op>, w: List<&2, String>, m: Bool, qs: Qs) -> Prog:
  match qs:
    case Qs{Nil{}, True{}}:
      Prog{n, List.append(&2, S.Op, o, bcast(g, angs, List.range(n))), w, m}
    case Qs{qs2, all}:
      Prog{n, List.append(&2, S.Op, o, ops(g, angs, qs2)), w, m}

def stmt.args(g: Gn, n: Nat, o: List<&2, S.Op>, w: List<&2, String>, m: Bool, ar: List<&2, List<&2, Tok>> & List<&2, Tok>) -> Prog:
  (lists, more) = ar
  stmt.qs(g, evals(lists), n, o, w, m, qubits(more, Nil{}, False{}))

def stmt.gate(g: Gn, +rest: List<&2, Tok>, n: Nat, o: List<&2, S.Op>, w: List<&2, String>, m: Bool) -> Prog:
  match rest:
    case LPar{} <> more:
      stmt.args(g, n, o, w, m, args(more, 0n, Nil{}, Nil{}))
    case _:
      stmt.qs(g, Nil{}, n, o, w, m, qubits(rest, Nil{}, False{}))

def stmt.qreg(rest: List<&2, Tok>, o: List<&2, S.Op>, w: List<&2, String>, m: Bool) -> Prog:
  match rest:
    case Name{r} <> LBr{} <> Num{k} <> RBr{} <> _:
      Prog{Maybe.default(&2, Nat, Nat.read(k), 0n), o, w, m}
    case _:
      Prog{0n, o, "skipped a qreg that is not name[size]" <> w, m}

def stmt.at(+g: Gn, name: String, rest: List<&2, Tok>, n: Nat, o: List<&2, S.Op>, w: List<&2, String>, m: Bool) -> Prog:
  match g:
    case Nqreg{}:
      stmt.qreg(rest, o, w, m)
    case Nmeasure{}:
      Prog{n, o, w, True{}}
    case Nskip{}:
      Prog{n, o, w, m}
    case Nunknown{}:
      Prog{n, o, ("skipped: " ++ name) <> w, m}
    case _:
      stmt.gate(g, rest, n, o, w, m)

# one statement folded into the program
def stmt(ts: List<&2, Tok>, p: Prog) -> Prog:
  match ts p:
    case Name{+name} <> rest Prog{n, o, w, m}:
      stmt.at(gname(name), name, rest, n, o, w, m)
    case _ Prog{n, o, w, m}:
      Prog{n, o, "skipped a statement that does not start with a name" <> w, m}

def fold(ss: List<&2, List<&2, Tok>>, p: Prog) -> Prog:
  match ss:
    case Nil{}:
      p
    case s <> rest:
      fold(rest, stmt(s, p))

def program(text: String) -> Prog:
  fold(stmts(tokens(text), Nil{}, Nil{}), Prog{0n, Nil{}, Nil{}, False{}})

# Running
# -------

def notes(w: List<&2, String>) -> IO(Unit):
  match w:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case s <> rest:
      do IO<Unit>:
        IO.print(s)
        notes(rest)

def measured(m: Bool) -> IO(Unit):
  match m:
    case True{}:
      IO.print("measure statements are ignored: the final state is sampled instead")
    case False{}:
      IO.pure(Unit, Unit{})

def amps(small: Bool, +n: Nat, o: List<&2, S.Op>) -> IO(Unit):
  match small:
    case True{}:
      IO.print("amplitudes: " ++ S.show3(n, S.run(n, o, S.ket0(n))))
    case False{}:
      IO.print("amplitudes: omitted past five qubits")

def execute(+n: Nat, +o: List<&2, S.Op>, shots: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.print("no qreg: nothing to run")
    case 1n++p:
      do IO<Unit>:
        IO.print(Nat.show(1n+p) ++ " qubits, " ++ Nat.show(List.length(&2, S.Op, o)) ++ " ops")
        amps(Nat.is_le(1n+p, 5n), 1n+p, o)
        IO.print(S.show_hist(S.sample(1n+p, shots, S.seed(), S.run(1n+p, o, S.ket0(1n+p)))))

def report(p: Prog, shots: U32) -> IO(Unit):
  match p:
    case Prog{n, o, w, m}:
      do IO<Unit>:
        notes(List.reverse(&2, String, w))
        measured(m)
        execute(n, o, shots)

def shots_of(r: Result<&1, &1, U32 & String, String>) -> U32:
  match r:
    case Done{v}:
      Maybe.default(&2, U32, U32.read(v), 1024)
    case Fail{e}:
      1024

def read_go(fm: File & Result<&1, &1, U32 & String, String>, shots: U32) -> IO(Unit):
  (f, r) = fm
  do IO<Unit>:
    text : String <- IO.pass(String, r)
    x : Unit <- File.close(f)
    report(program(text), shots)

def open_go(pr: Result<&1, &1, U32 & String, String>, shots: U32) -> IO(Unit):
  match pr:
    case Fail{e}:
      IO.print("set QASM to the path of an OpenQASM 2 file, and SHOTS to the shot count (default 1024)")
    case Done{path}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open(path, "r"))
        fm : File & Result<&1, &1, U32 & String, String> <- File.read(f, 1000000)
        read_go(fm, shots)

def main() -> IO(Unit):
  do IO<Unit>:
    pr : Result<&1, &1, U32 & String, String> <- IO.get_env("QASM")
    sr : Result<&1, &1, U32 & String, String> <- IO.get_env("SHOTS")
    open_go(pr, shots_of(sr))
