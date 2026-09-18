// the QFT of |001> on three qubits, big-endian: qubit 0 is the top bit
OPENQASM 2.0;
include "qelib1.inc";
qreg q[3];
creg c[3];
x q[2];
h q[0];
cu1(pi/2) q[1],q[0];
cu1(pi/4) q[2],q[0];
h q[1];
cu1(pi/2) q[2],q[1];
h q[2];
swap q[0],q[2];
barrier q;
measure q -> c;
