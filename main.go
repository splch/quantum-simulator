package main

import (
	"fmt"

	"github.com/splch/quantum_simulator/pkg/quantum_simulator"
)

func main() {
	// Initialize a quantum circuit
	circuit := quantum_simulator.NewCircuit(3)

	// Apply a Hadamard gate
	circuit.H(0)

	// Apply a T gate
	circuit.T(1)

	// Apply a Controlled-Not gate
	circuit.CX(0, 1)

	// Apply a Generic gate
	circuit.U(2, 0.3, 0.4, 0.5)

	// Run the circuit 100 times
	results := circuit.Run(100)

	// Print measurements
	for state, count := range results {
		// Expected result:
		// 000: 46
		// 001: 4
		// 100: 4
		// 101: 46
		fmt.Printf("%s: %d\n", state, count)
	}
}
