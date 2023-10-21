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
func (circuit *Circuit) ApplyGate(gate Gate, target int) {
	newState := make([]complex128, len(circuit.State))

	for i := 0; i < len(circuit.State); i++ {
		for j := 0; j < len(gate.Matrix); j++ {
			// Find the index to which the amplitude should be added in the new state
			newIdx := i ^ (j << target)

			// Calculate the new amplitude and add it to the new state
			newState[newIdx] += gate.Matrix[j][i&(1<<target)>>target] * circuit.State[i]
		}
	}

	// Update the circuit's state
	circuit.State = newState
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
	circuit.ApplyGate(X.Control(), target)
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
		state := circuit.measure()
		results[state]++
	}

	return results
}

// measure performs a measurement on the circuit
func (circuit *Circuit) measure() string {
	r := rand.Float64()

	for i, prob := range circuit.State {
		r -= cmplx.Abs(prob) * cmplx.Abs(prob)

		if r <= 0 {
			return fmt.Sprintf("%0*b", circuit.nQubits, i)
		}
	}

	return ""
}
