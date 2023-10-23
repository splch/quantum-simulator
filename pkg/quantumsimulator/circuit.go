// Package quantumsimulator provides structures and functions
// for simulating quantum gates and circuits.
package quantumsimulator

import (
	"errors"
	"fmt"
	"math/cmplx"
	"math/rand"
)

// Circuit struct represents a quantum circuit with multiple qubits.
// State holds the current state vector of the quantum circuit,
// and nQubits holds the total number of qubits in the circuit.
type Circuit struct {
	State   []complex128 // The state vector of the circuit.
	nQubits int          // Number of qubits in the circuit.
}

// NewCircuit initializes a new Circuit with nQubits and returns it.
// The function sets the initial state vector where only the first element is set to 1.
func NewCircuit(nQubits int) (*Circuit, error) {
	if nQubits <= 0 {
		return nil, errors.New("number of qubits must be positive")
	}

	state := make([]complex128, 1<<nQubits)
	state[0] = 1 // Set the initial state to |0...0⟩.

	return &Circuit{
		State:   state,
		nQubits: nQubits,
	}, nil
}

// ApplyGate applies a quantum gate to the circuit.
// The method takes gate as the quantum gate to apply, target as the target qubit,
// and optional control qubits for controlled gates.
func (circuit *Circuit) ApplyGate(gate Gate, target int, control ...int) error {
	if target >= circuit.nQubits || target < 0 {
		return errors.New("target qubit index out of range")
	}
	n := circuit.nQubits
	var operator [][]complex128

	if len(control) > 0 { // If a control qubit is provided.
		controlQubit := control[0]
		CGate := gate.Control(controlQubit, target, n)
		operator = CGate.Matrix
	} else { // If no control qubit is provided.
		operator = IdentityMatrix(1)
		for qubit := 0; qubit < n; qubit++ {
			if qubit == target {
				operator = kronecker(operator, gate.Matrix)
			} else {
				operator = kronecker(operator, IdentityMatrix(2))
			}
		}
	}

	circuit.State = Multiply(operator, circuit.State) // Applying the operator to the state vector.
	return nil                                        // No error occurred.
}

// H applies a Hadamard gate to a target qubit in the circuit, or its inverse if inv is true.
func (circuit *Circuit) H(target int, inv ...bool) {
	gate := H
	if len(inv) > 0 && inv[0] {
		gate = H.Inverse()
	}
	circuit.ApplyGate(gate, target)
}

// T applies a T gate (π/8 gate) to a target qubit in the circuit, or its inverse if inv is true.
func (circuit *Circuit) T(target int, inv ...bool) {
	gate := T
	if len(inv) > 0 && inv[0] {
		gate = T.Inverse()
	}
	circuit.ApplyGate(gate, target)
}

// X applies a Pauli-X gate to a target qubit in the circuit, or its inverse if inv is true.
func (circuit *Circuit) X(target int, inv ...bool) {
	gate := X
	if len(inv) > 0 && inv[0] {
		gate = X.Inverse()
	}
	circuit.ApplyGate(gate, target)
}

// CX applies a controlled-X (CNOT) gate to target qubits in the circuit, or its inverse if inv is true.
func (circuit *Circuit) CX(control, target int, inv ...bool) {
	gate := X
	if len(inv) > 0 && inv[0] {
		gate = X.Inverse()
	}
	circuit.ApplyGate(gate, target, control)
}

// U applies a custom unitary gate defined by the parameters theta, phi, and lambda to a target qubit,
// or its inverse if inv is true.
func (circuit *Circuit) U(target int, theta, phi, lambda float64, inv ...bool) {
	gate := U(theta, phi, lambda)
	if len(inv) > 0 && inv[0] {
		gate = gate.Inverse()
	}
	circuit.ApplyGate(gate, target)
}

// CU applies a controlled-U gate to target qubits in the circuit, or its inverse if inv is true.
func (circuit *Circuit) CU(control, target int, theta, phi, lambda float64, inv ...bool) {
	gate := U(theta, phi, lambda)
	if len(inv) > 0 && inv[0] {
		gate = gate.Inverse()
	}
	circuit.ApplyGate(gate, target, control)
}

// Run simulates the measurement of the quantum circuit multiple times.
// The method takes shots as the number of times the measurement is repeated,
// and returns a map with the measurement outcomes and their occurrences.
func (circuit *Circuit) Run(shots int) (map[string]int, error) {
	if shots <= 0 {
		return nil, errors.New("shots must be a positive integer")
	}

	results := make(map[string]int)
	for i := 0; i < shots; i++ {
		measurement := circuit.measure()
		results[measurement]++
	}

	return results, nil // No error occurred.
}

// measure simulates a single measurement of the quantum circuit and returns the binary string of the measured state.
func (circuit *Circuit) measure() string {
	probabilities := calculateProbabilities(circuit.State) // Calculate the probabilities from the state amplitudes.

	randomNumber := rand.Float64()
	sum := 0.0
	for i, probability := range probabilities {
		sum += probability
		if randomNumber < sum { // Randomly select a state based on the calculated probabilities.
			return fmt.Sprintf("%0*b", circuit.nQubits, i)
		}
	}

	// It should normally not reach this point. Included for completeness.
	return ""
}

// PrintState prints the current quantum state and the probability of each state.
func (circuit *Circuit) PrintState() {
	probabilities := calculateProbabilities(circuit.State)

	for i, probability := range probabilities {
		// Convert the state index to binary representation
		state := fmt.Sprintf("|%0*b⟩", circuit.nQubits, i)

		// Print the state and its probability
		fmt.Printf("%s: %f\n", state, probability)
	}
}

// calculateProbabilities takes a state vector and returns the corresponding probabilities.
func calculateProbabilities(state []complex128) []float64 {
	probabilities := make([]float64, len(state))
	for i, amplitude := range state {
		probabilities[i] = cmplx.Abs(amplitude) * cmplx.Abs(amplitude)
	}
	return probabilities
}
