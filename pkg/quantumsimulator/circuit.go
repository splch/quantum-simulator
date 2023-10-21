package quantumsimulator

import (
	"fmt"
	"math"
	"math/cmplx"
	"math/rand"
)

// Circuit represents a quantum circuit
type Circuit struct {
	State   []complex128
	nQubits int
}

// NewCircuit creates a new quantum circuit
func NewCircuit(nQubits int) Circuit {
	state := make([]complex128, 1<<nQubits)
	state[0] = 1

	return Circuit{
		State:   state,
		nQubits: nQubits,
	}
}

// ApplyGate applies a gate to the circuit
func (circuit *Circuit) ApplyGate(gate Gate, target int, control ...int) {
	n := circuit.nQubits

	// Building the operator
	var operator [][]complex128
	if len(control) > 0 { // If it is a controlled gate
		controlQubit := control[0]
		CGate := gate.Control(controlQubit, target, n)
		operator = CGate.Matrix
	} else { // If it is not a controlled gate
		operator = IdentityMatrix(1)
		for qubit := 0; qubit < n; qubit++ {
			if qubit == target {
				operator = kronecker(operator, gate.Matrix)
			} else {
				operator = kronecker(operator, IdentityMatrix(2))
			}
		}
	}

	// Applying the operator to the circuit state
	circuit.State = Multiply(operator, circuit.State)
}

// H applies a Hadamard gate
func (circuit *Circuit) H(target int) {
	circuit.ApplyGate(H, target)
}

// T applies a T gate
func (circuit *Circuit) T(target int) {
	circuit.ApplyGate(T, target)
}

// X applies a X gate
func (circuit *Circuit) X(target int) {
	circuit.ApplyGate(X, target)
}

// CX applies a Controlled-X gate
func (circuit *Circuit) CX(control, target int) {
	circuit.ApplyGate(X, target, control)
}

// U applies a generic unitary gate
func (circuit *Circuit) U(target int, theta, phi, lambda float64) {
	matrix := [][]complex128{
		{
			complex(math.Cos(theta/2), 0),
			complex(-math.Sin(theta/2), 0) * cmplx.Exp(complex(0, lambda)),
		},
		{
			cmplx.Exp(complex(0, phi)) * complex(math.Sin(theta/2), 0),
			cmplx.Exp(complex(0, phi+lambda)) * complex(math.Cos(theta/2), 0),
		},
	}

	gate := NewGate(matrix)
	circuit.ApplyGate(gate, target)
}

// Run executes the circuit and returns the measurement results
func (circuit *Circuit) Run(shots int) map[string]int {
	results := make(map[string]int)

	for i := 0; i < shots; i++ {
		measurement := circuit.measure()
		results[measurement]++
	}

	return results
}

// measure performs a measurement on the circuit
func (circuit *Circuit) measure() string {
	probabilities := make([]float64, len(circuit.State))

	for i, amplitude := range circuit.State {
		probabilities[i] = cmplx.Abs(amplitude) * cmplx.Abs(amplitude)
	}

	// Generate a random number between 0 and 1
	randomNumber := rand.Float64()

	// Find which basis state is selected
	sum := 0.0
	for i, probability := range probabilities {
		sum += probability
		if randomNumber < sum {
			// Convert the index of the basis state to a binary string
			return fmt.Sprintf("%0*b", circuit.nQubits, i)
		}
	}

	return ""
}
