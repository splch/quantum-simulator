package quantum_simulator

// Circuit type
type Circuit struct {
	qubits int
	state  []complex128
}

// NewCircuit initializes a new Circuit.
func NewCircuit(qubits int) *Circuit {
	initialState := make([]complex128, 1<<qubits)
	initialState[0] = 1
	return &Circuit{qubits, initialState}
}

// H applies a Hadamard gate.
func (c *Circuit) H(qubit int) {
	ApplyGate(c.state, H, qubit)
}

// T applies a T gate.
func (c *Circuit) T(qubit int) {
	ApplyGate(c.state, T, qubit)
}

// CX applies a Controlled-Not gate.
func (c *Circuit) CX(control, target int) {
	// Implementation here
}

// U applies a generic unitary gate.
func (c *Circuit) U(qubit int, theta, phi, lambda float64) {
	// Implementation here
}

// Run runs the circuit and returns measurements.
func (c *Circuit) Run(n int) map[string]int {
	results := make(map[string]int)
	for i := 0; i < n; i++ {
		// Simulate measurement and populate 'results'
	}
	return results
}
