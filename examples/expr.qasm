// angle expressions and the rest of the subset: u3(pi/2, 0, pi) is H,
// a gate on the bare register applies to every qubit, and unknown
// statements are reported
OPENQASM 2.0;
include "qelib1.inc";
qreg q[3];
creg c[3];
u3(pi/2, 0, pi) q[0];
rz(-3*pi/2) q[0];
ry(2*(pi/3)) q[1];
u2(0, pi) q[2];
cy q[0],q[1];
crz(pi/8) q[1],q[2];
t q;
id q[0];
if (c==1) x q[0];
sx q[1];
